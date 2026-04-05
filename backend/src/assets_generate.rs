//! Legacy **`/api/assetsGenerate/*`**: SQLite **`o_image`** / **`o_assets`** 出图与提示词润色。
//! SaaS: bodies match old **`validateFields`** shapes; handlers return **501** until jobs + image pipeline exist.

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

#[derive(Debug, Deserialize)]
enum AssetGenKind {
    #[serde(rename = "role")]
    Role,
    #[serde(rename = "scene")]
    Scene,
    #[serde(rename = "tool")]
    Tool,
    #[serde(rename = "storyboard")]
    Storyboard,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GenerateAssetsBody {
    project_id: i32,
    model: String,
    resolution: String,
    id: i32,
    #[serde(rename = "type")]
    asset_type: AssetGenKind,
    name: String,
    prompt: String,
    #[serde(default)]
    base64: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PolishAssetsPromptBody {
    assets_id: i32,
    project_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    name: String,
    describe: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchGenItem {
    id: i32,
    #[serde(rename = "type")]
    asset_type: AssetGenKind,
    name: String,
    prompt: String,
    #[serde(default)]
    base64: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchGenerateImageAssetsBody {
    project_id: i32,
    model: String,
    resolution: String,
    #[serde(default)]
    concurrent_count: Option<i32>,
    items: Vec<BatchGenItem>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchPolishItem {
    assets_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    name: String,
    describe: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchPolishAssetsPromptBody {
    project_id: i32,
    #[serde(default)]
    concurrent_count: Option<i32>,
    items: Vec<BatchPolishItem>,
}

fn not_implemented() -> ApiError {
    ApiError::NotImplemented(
        "asset image generation and prompt polish are not implemented; use generation jobs when wired"
            .into(),
    )
}

async fn post_generate_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateAssetsBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_polish_assets_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PolishAssetsPromptBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_batch_generate_image_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateImageAssetsBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

async fn post_batch_polish_assets_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchPolishAssetsPromptBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(not_implemented())
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/assets-generate/generate",
            post(post_generate_assets),
        )
        .route(
            "/api/v1/assets-generate/polish-prompt",
            post(post_polish_assets_prompt),
        )
        .route(
            "/api/v1/assets-generate/batch-generate",
            post(post_batch_generate_image_assets),
        )
        .route(
            "/api/v1/assets-generate/batch-polish",
            post(post_batch_polish_assets_prompt),
        )
}
