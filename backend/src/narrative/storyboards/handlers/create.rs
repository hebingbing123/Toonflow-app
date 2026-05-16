use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_write_scope;
use crate::scope;
use crate::state::AppState;

use super::super::dto::{CreateStoryboardBody, StoryboardRow};
use super::common::create_storyboard_locked;

pub(in crate::narrative::storyboards) async fn create_under_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<CreateStoryboardBody>,
) -> Result<(StatusCode, Json<StoryboardRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Verify workspace member write access to the project
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let oip = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = create_storyboard_locked(
        &mut tx,
        oip.script_id,
        oip.project_numeric_id,
        script_numeric_id,
        body,
    )
    .await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}
