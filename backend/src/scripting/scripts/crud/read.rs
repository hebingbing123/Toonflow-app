//! 按项目读取单条剧本。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope;
use crate::state::AppState;

use super::super::types::ScriptRow;

pub(in crate::scripting::scripts) async fn get_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<ScriptRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let oip = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let row = sqlx::query_as::<_, ScriptRow>(
        r#"
        SELECT id, project_id, numeric_id, name, content, extract_state, create_time_ms
        FROM app_script
        WHERE id = $1
        "#,
    )
    .bind(oip.script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}
