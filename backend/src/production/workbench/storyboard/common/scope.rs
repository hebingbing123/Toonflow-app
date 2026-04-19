use uuid::Uuid;

use crate::error::ApiError;
use crate::scope;

use super::normalize::require_positive_scope_ids;

async fn resolve_owned_storyboard_id(
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

pub(in crate::production::workbench::storyboard) async fn require_owned_storyboard_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<Uuid, ApiError> {
    require_positive_scope_ids(project_id, script_id, storyboard_id)?;
    resolve_owned_storyboard_id(pool, uid, project_id, script_id, storyboard_id).await
}
