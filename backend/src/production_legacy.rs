//! Legacy **`/api/production/*`**: SQLite **`o_video`**, **`o_videoConfig`**, **`o_agentWorkData`** (production flow), OSS paths.
//! SaaS: six routes use **strict** serde bodies; all other legacy **`POST`** paths share **`post_production_legacy_json_stub`**
//! (**JSON object** only, then **501**) until video pipeline + storage exist.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::{IntoResponse, Response},
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

fn not_implemented() -> ApiError {
    ApiError::NotImplemented(
        "production workbench / video pipeline is not implemented; use storyboard REST and generation jobs when wired"
            .into(),
    )
}

fn require_json_object(body: &Value) -> Result<(), ApiError> {
    if body.as_object().is_none() {
        return Err(ApiError::BadRequest("body must be a JSON object".into()));
    }
    Ok(())
}

async fn post_production_legacy_json_stub(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<Value>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    require_json_object(&body)?;
    Err(not_implemented())
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct StoryboardIdListBody {
    ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct ProductionStoryboardItem {
    id: i32,
    #[sqlx(rename = "script_id")]
    script_id: Option<i32>,
    prompt: Option<String>,
    #[sqlx(rename = "url")]
    file_path: Option<String>,
    duration: Option<String>,
    state: Option<String>,
    #[sqlx(rename = "track_id")]
    track_id: Option<i32>,
    #[sqlx(rename = "flow_id")]
    flow_id: Option<i32>,
    #[sqlx(rename = "sb_index")]
    sb_index: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProductionGetProductionDataResponse {
    data: Vec<ProductionStoryboardItem>,
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
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("ids must be a non-empty array".into()));
    }
    if body.ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("ids must be positive integers".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows = sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.legacy_id AS id,
          sb.legacy_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND sb.legacy_id = ANY($2::int4[])
        ORDER BY array_position($2::int4[], sb.legacy_id)
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(ProductionGetProductionDataResponse { data: rows }).into_response())
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

const LEGACY_JSON_STUB_PATHS: &[&str] = &[
    "/api/v1/production/assets/batch-generate-assets-image",
    "/api/v1/production/assets/delete-assets-derivative",
    "/api/v1/production/assets/get-assets-data",
    "/api/v1/production/assets/polling-image",
    "/api/v1/production/assets/update-assets-url",
    "/api/v1/production/edit-image/generate-flow-image",
    "/api/v1/production/edit-image/get-image-default-model",
    "/api/v1/production/edit-image/get-image-flow",
    "/api/v1/production/edit-image/save-image-flow",
    "/api/v1/production/edit-image/update-image-flow",
    "/api/v1/production/get-storyboard-data",
    "/api/v1/production/storyboard/add",
    "/api/v1/production/storyboard/batch-add-info",
    "/api/v1/production/storyboard/batch-generate-image",
    "/api/v1/production/storyboard/down-preview-image",
    "/api/v1/production/storyboard/edit-info",
    "/api/v1/production/storyboard/get-data",
    "/api/v1/production/storyboard/preview-image",
    "/api/v1/production/storyboard/remove-frame",
    "/api/v1/production/storyboard/update-url",
    "/api/v1/production/workbench/add-track",
    "/api/v1/production/workbench/delete-track",
    "/api/v1/production/workbench/delete-video",
    "/api/v1/production/workbench/generate-video-prompt",
    "/api/v1/production/workbench/get-generate-data",
    "/api/v1/production/workbench/get-video-list",
    "/api/v1/production/workbench/get-video-model-detail",
    "/api/v1/production/workbench/select-video",
];

pub fn router() -> Router<AppState> {
    let mut r = Router::new()
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
        .route("/api/v1/production/export-image", post(post_export_image));
    for path in LEGACY_JSON_STUB_PATHS {
        r = r.route(path, post(post_production_legacy_json_stub));
    }
    r
}
