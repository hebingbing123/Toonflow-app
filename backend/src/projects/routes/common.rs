use crate::http_kit::json_patch::FieldPatch;
use crate::{error::ApiError, state::AppState};
use uuid::Uuid;

/// Stable key for `pg_advisory_xact_lock` when allocating `app_project.numeric_id` (global uniqueness).
pub(super) const ADV_LOCK_PROJECT_NUMERIC_ID: i64 = 884_422_001;

pub(super) fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub(super) fn merge_text_patch(
    current: &Option<String>,
    patch: FieldPatch<String>,
) -> Option<String> {
    match patch {
        FieldPatch::Absent => current.clone(),
        FieldPatch::Set(v) => v,
    }
}

#[derive(Debug, Clone, Copy, sqlx::FromRow)]
pub(crate) struct ProjectAccessScope {
    pub id: Uuid,
}

pub(crate) async fn require_project_workspace_member_scope(
    state: &AppState,
    user_id: Uuid,
    project_id: Uuid,
) -> Result<ProjectAccessScope, ApiError> {
    let pool = state.require_pool()?;
    let exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM app_project WHERE id = $1)")
        .bind(project_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !exists {
        return Err(ApiError::NotFound);
    }

    let row: Option<ProjectAccessScope> = sqlx::query_as(
        r#"
        SELECT p.id
        FROM app_project p
        WHERE p.id = $1
          AND EXISTS (
            SELECT 1
            FROM public.app_workspace_member m
            WHERE m.workspace_id = p.workspace_id
              AND m.user_id = $2
          )
        LIMIT 1
        "#,
    )
    .bind(project_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or_else(|| ApiError::Forbidden("not a member of project workspace".into()))
}
