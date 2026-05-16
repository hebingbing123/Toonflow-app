//! 按项目读取单条剧本。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::super::types::ScriptRow;

pub(in crate::scripting::scripts) async fn get_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<ScriptRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Validate workspace member access to project
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let row = sqlx::query_as::<_, ScriptRow>(
        r#"
        SELECT s.id, s.project_id, s.numeric_id, s.name, s.content, s.extract_state, s.create_time_ms
        FROM app_script s
        WHERE s.project_id = $1
          AND s.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(script_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}
