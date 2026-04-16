use axum::{extract::State, http::HeaderMap, routing::post, Json, Router};
use serde::Serialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::storage::{
    load_director_manual_list, story_manual_dir, sync_images, validate_style_key, write_slots,
};
use super::types::{
    AddDirectorManualBody, DeleteDirectorManualBody, DirectorManualListResponse,
    EditDirectorManualBody,
};

#[derive(Debug, Serialize)]
struct EmptyOkResponse {}

#[derive(Debug, Serialize)]
struct DeleteDirectorManualResponse {
    message: &'static str,
}

async fn post_query_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<DirectorManualListResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(load_director_manual_list()?))
}

async fn post_add_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddDirectorManualBody>,
) -> Result<Json<EmptyOkResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.name)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.director_manual)?;

    let main_path = story_manual_dir(&body.director_manual)?;
    if main_path.exists() {
        return Err(ApiError::BadRequest("请勿填写重复名称的视觉手册".into()));
    }

    std::fs::create_dir_all(&main_path).map_err(|e| {
        ApiError::BadRequest(format!(
            "director-manual: create {}: {e}",
            main_path.display()
        ))
    })?;

    if let Err(e) = write_slots(&main_path, &body.name, &body.data, false) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }
    if let Err(e) = sync_images(&main_path, &body.images) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }

    Ok(Json(EmptyOkResponse {}))
}

async fn post_edit_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditDirectorManualBody>,
) -> Result<Json<EmptyOkResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.name)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.director_manual)?;

    let main_path = story_manual_dir(&body.director_manual)?;
    if !main_path.is_dir() {
        return Err(ApiError::BadRequest("导演手册不存在".into()));
    }

    write_slots(&main_path, &body.name, &body.data, true)?;
    sync_images(&main_path, &body.images)?;

    Ok(Json(EmptyOkResponse {}))
}

async fn post_delete_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteDirectorManualBody>,
) -> Result<Json<DeleteDirectorManualResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.name)?;
    if let Ok(dir) = story_manual_dir(&body.name) {
        if dir.is_dir() {
            let _ = std::fs::remove_dir_all(&dir);
        }
    }
    Ok(Json(DeleteDirectorManualResponse {
        message: "删除成功",
    }))
}

pub(super) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/project/query-director-manual",
            post(post_query_director_manual),
        )
        .route(
            "/api/v1/project/add-director-manual",
            post(post_add_director_manual),
        )
        .route(
            "/api/v1/project/edit-director-manual",
            post(post_edit_director_manual),
        )
        .route(
            "/api/v1/project/delete-director-manual",
            post(post_delete_director_manual),
        )
}
