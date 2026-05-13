use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::state::AppState;

use super::storage::{load_visual_manual, sync_visual_images, write_visual_slots};
use super::types::{
    AddVisualManualBody, DeleteVisualManualBody, DeleteVisualManualResponse, EditVisualManualBody,
    EmptyOkObject, VisualManualResponse,
};
use super::validation::{art_skills_style_dir, validate_manual_folder_name};

pub(super) async fn post_add_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddVisualManualBody>,
) -> Result<JsonResponse<EmptyOkObject>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_manual_folder_name(&body.name)?;
    validate_manual_folder_name(&body.style_path)?;

    let main_path = art_skills_style_dir(&body.style_path)?;
    if main_path.exists() {
        return Err(bad_request_i18n(
            "Duplicate visual manual name is not allowed",
            "请勿填写重复名称的视觉手册",
        ));
    }

    std::fs::create_dir_all(&main_path).map_err(|e| {
        bad_request_i18n(
            &format!("visual-manual: create {}: {e}", main_path.display()),
            &format!("visual-manual：创建 {} 失败：{e}", main_path.display()),
        )
    })?;

    if let Err(e) = write_visual_slots(&main_path, &body.name, &body.data, false) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }
    if let Err(e) = sync_visual_images(&main_path, &body.images) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }

    Ok(JsonResponse(EmptyOkObject {}))
}

pub(super) async fn post_edit_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditVisualManualBody>,
) -> Result<JsonResponse<EmptyOkObject>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_manual_folder_name(&body.name)?;
    validate_manual_folder_name(&body.style_path)?;

    let main_path = art_skills_style_dir(&body.style_path)?;
    if !main_path.is_dir() {
        return Err(bad_request_i18n(
            "Visual manual does not exist",
            "视觉手册不存在",
        ));
    }

    write_visual_slots(&main_path, &body.name, &body.data, true)?;
    sync_visual_images(&main_path, &body.images)?;

    Ok(JsonResponse(EmptyOkObject {}))
}

pub(super) async fn post_delete_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteVisualManualBody>,
) -> Result<JsonResponse<DeleteVisualManualResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_manual_folder_name(&body.name)?;
    if let Ok(dir) = art_skills_style_dir(&body.name) {
        if dir.is_dir() {
            let _ = std::fs::remove_dir_all(&dir);
        }
    }
    Ok(JsonResponse(DeleteVisualManualResponse {
        message: "删除成功",
    }))
}

pub(super) async fn get_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<VisualManualResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(JsonResponse(load_visual_manual()?))
}

/// Same payload as [`get_visual_manual`]; **POST** matches Electron-era **`POST /api/project/getVisualManual`** (body ignored).
pub(super) async fn post_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<VisualManualResponse>, ApiError> {
    get_visual_manual(State(state), headers).await
}
