//! Legacy **`/api/production/*`**: SQLite **`o_video`**, **`o_videoConfig`**, **`o_agentWorkData`** (production flow), OSS paths.
//! SaaS: selected **POST** bodies match old **`validateFields`** shapes; handlers return **501** until video pipeline + storage exist.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::Response,
    routing::post,
    Router,
};
use serde::Deserialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

fn not_implemented() -> ApiError {
    ApiError::NotImplemented(
        "production workbench / video pipeline is not implemented; use storyboard REST and generation jobs when wired"
            .into(),
    )
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct StoryboardIdListBody {
    ids: Vec<i32>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetFlowDataBody {
    project_id: i32,
    episodes_id: i32,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SaveFlowDataBody {
    project_id: i32,
    episodes_id: i32,
    data: serde_json::Value,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GenerateVideoUploadItem {
    id: i32,
    sources: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct WorkbenchGenerateVideoBody {
    project_id: i32,
    script_id: i32,
    upload_data: Vec<GenerateVideoUploadItem>,
    prompt: String,
    model: String,
    mode: String,
    resolution: String,
    duration: i32,
    #[serde(default)]
    audio: Option<bool>,
    track_id: i32,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ExportImageShotRef {
    id: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ExportImageBody {
    shot_id: Vec<ExportImageShotRef>,
}

async fn post_get_production_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardIdListBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_get_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetFlowDataBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_save_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SaveFlowDataBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_workbench_generate_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchGenerateVideoBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_storyboard_polling_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardIdListBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_export_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExportImageBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/production/get-production-data",
            post(post_get_production_data),
        )
        .route("/api/v1/production/get-flow-data", post(post_get_flow_data))
        .route(
            "/api/v1/production/save-flow-data",
            post(post_save_flow_data),
        )
        .route(
            "/api/v1/production/workbench/generate-video",
            post(post_workbench_generate_video),
        )
        .route(
            "/api/v1/production/storyboard/polling-image",
            post(post_storyboard_polling_image),
        )
        .route("/api/v1/production/export-image", post(post_export_image))
}
