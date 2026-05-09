//! 删除项目（含 agent memory 清理）。

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::audit::{
    append_project_audit, project_deleted_details, AppendProjectAudit,
};
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

#[utoipa::path(
    delete,
    path = "/api/v1/projects/{project_id}",
    operation_id = "deleteProjectByIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 204, description = "Deleted"),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_project_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    if !scope.can_delete_project() {
        return Err(ApiError::Forbidden(
            "only the project owner or workspace owner/admin can delete this project".into(),
        ));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_row: Option<(i32, Option<String>)> = sqlx::query_as(
        r#"
        SELECT p.numeric_id, p.name
        FROM app_project p
        WHERE p.id = $1
        "#,
    )
    .bind(scope.id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((numeric_id, project_name)) = project_row else {
        tx.rollback()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Err(ApiError::NotFound);
    };

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE numeric_project_id = $1
        "#,
    )
    .bind(numeric_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_project
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        tx.rollback()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Err(ApiError::NotFound);
    }

    append_project_audit(
        &mut *tx,
        AppendProjectAudit {
            project_id: scope.id,
            workspace_id: scope.workspace_id,
            project_numeric_id: Some(numeric_id),
            actor_user_id: uid,
            action: "project_deleted",
            target_user_id: None,
            details: project_deleted_details(project_name.as_deref(), numeric_id),
        },
    )
    .await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}
