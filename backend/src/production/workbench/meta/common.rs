use axum::http::HeaderMap;
use sqlx::PgPool;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope::{self, OwnedScriptScope};
use crate::state::AppState;

pub(super) async fn require_owned_script_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
) -> Result<(uuid::Uuid, &'a PgPool, OwnedScriptScope), ApiError> {
    let uid = require_user_uuid(state, headers)?;
    if project_id <= 0 || script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let scope = scope::owned_script_scope(pool, uid, project_id, script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    Ok((uid, pool, scope))
}
