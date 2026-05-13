//! 叙事分镜 PATCH / DELETE HTTP 入口。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};

use super::super::super::dto::{PatchStoryboardBody, StoryboardRow};
use super::delete::delete_storyboard_row;
use super::patch::patch_storyboard_row;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

pub(in crate::narrative::storyboards) async fn patch_by_numeric_id_for_project(
    State(state): State<AppState>,
    Path((project_id, storyboard_numeric_id)): Path<(uuid::Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchStoryboardBody>,
) -> Result<Json<StoryboardRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Verify workspace member write access to the project
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    patch_storyboard_row(pool, uid, storyboard_numeric_id, body, project_id).await
}

pub(in crate::narrative::storyboards) async fn delete_by_numeric_id_for_project(
    State(state): State<AppState>,
    Path((project_id, storyboard_numeric_id)): Path<(uuid::Uuid, i32)>,
    headers: HeaderMap,
) -> Result<axum::http::StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Verify workspace member write access to the project
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    delete_storyboard_row(pool, uid, storyboard_numeric_id, project_id).await
}
