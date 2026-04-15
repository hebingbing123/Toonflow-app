use uuid::Uuid;

use crate::error::ApiError;
use crate::production::workbench::common as workbench_common;
use crate::scope;
use crate::state::AppState;

pub(super) fn require_pool(state: &AppState) -> Result<&sqlx::PgPool, ApiError> {
    workbench_common::require_pool(state)
}

pub(super) fn require_positive_project_script(
    project_id: i32,
    script_id: i32,
) -> Result<(), ApiError> {
    workbench_common::require_positive_project_script(project_id, script_id)
}

pub(super) fn require_positive_scope_ids(
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<(), ApiError> {
    if project_id <= 0 || script_id <= 0 || storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and storyboardId must be positive integers".into(),
        ));
    }
    Ok(())
}

pub(super) async fn resolve_owned_script_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
) -> Result<Uuid, ApiError> {
    let scope_row = scope::owned_script_scope(pool, uid, project_id, script_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok(scope_row.script_id)
}

pub(super) async fn resolve_owned_storyboard_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<Uuid, ApiError> {
    let sb =
        scope::owned_storyboard_in_script_scope(pool, uid, project_id, script_id, storyboard_id)
            .await
            .map_err(|e| e.into_api_error())?;
    Ok(sb.storyboard_id)
}
