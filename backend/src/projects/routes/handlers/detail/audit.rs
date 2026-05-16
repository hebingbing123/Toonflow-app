use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::audit::{
    normalize_project_audit_action, ListProjectAuditEnvelope, ListProjectAuditQuery,
    ProjectAuditResponse,
};
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/audit",
    operation_id = "listProjectAuditV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ListProjectAuditQuery
    ),
    responses(
        (status = 200, description = "OK", body = ListProjectAuditEnvelope),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_project_audit(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Query(q): Query<ListProjectAuditQuery>,
) -> Result<Json<ListProjectAuditEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let action_filter = normalize_project_audit_action(q.action);
    let page_size = q.limit.unwrap_or(50).clamp(1, 200);
    let offset = q.offset.unwrap_or(0).max(0);
    let fetch_limit = page_size.saturating_add(1);

    let rows: Vec<ProjectAuditResponse> = sqlx::query_as(
        r#"
        SELECT
          id,
          project_id,
          workspace_id,
          project_numeric_id,
          actor_user_id,
          action,
          target_user_id,
          details,
          created_at
        FROM public.app_project_audit
        WHERE project_id = $1
          AND workspace_id = $2
          AND ($3::text IS NULL OR action = $3)
        ORDER BY created_at DESC, id DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(scope.id)
    .bind(scope.workspace_id)
    .bind(action_filter)
    .bind(fetch_limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut rows = rows;
    let has_more = (rows.len() as i64) > page_size;
    if has_more {
        rows.truncate(page_size as usize);
    }

    Ok(Json(ListProjectAuditEnvelope {
        items: rows,
        has_more,
    }))
}
