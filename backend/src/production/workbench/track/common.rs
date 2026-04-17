use axum::http::HeaderMap;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope::{self, OwnedScriptScope};
use crate::state::AppState;

pub(super) fn validate_positive_id(name: &str, id: i32) -> Result<(), ApiError> {
    if id <= 0 {
        return Err(ApiError::BadRequest(format!(
            "{name} must be a positive integer"
        )));
    }
    Ok(())
}

pub(super) async fn require_owned_script_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
) -> Result<(Uuid, &'a sqlx::PgPool, OwnedScriptScope), ApiError> {
    super::super::common::require_positive_project_script(project_id, script_id)?;
    let uid = require_user_uuid(state, headers)?;
    let pool = super::super::common::require_pool(state)?;
    let scope_row = scope::owned_script_scope(pool, uid, project_id, script_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok((uid, pool, scope_row))
}
