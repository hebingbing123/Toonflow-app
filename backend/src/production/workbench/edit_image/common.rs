use axum::http::HeaderMap;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

pub(super) fn require_numeric_scope(
    state: &AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
) -> Result<uuid::Uuid, ApiError> {
    let uid = require_user_uuid(state, headers)?;
    if project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be > 0".into()));
    }
    if script_id <= 0 {
        return Err(ApiError::BadRequest("scriptId must be > 0".into()));
    }
    Ok(uid)
}
