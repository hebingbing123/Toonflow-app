use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::state::AppState;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ImageFlowResponse {
    flow_id: String,
    steps: Vec<ImageFlowStep>,
    default_model: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ImageFlowStep {
    step_id: String,
    step_name: String,
    status: String,
}

pub(super) async fn post_edit_image_get_image_flow(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<ImageFlowResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    // Return a mock image flow structure
    Ok(JsonResponse(ImageFlowResponse {
        flow_id: "img-flow-001".to_string(),
        steps: vec![
            ImageFlowStep {
                step_id: "upload".to_string(),
                step_name: "上传图片".to_string(),
                status: "pending".to_string(),
            },
            ImageFlowStep {
                step_id: "select_area".to_string(),
                step_name: "选择区域".to_string(),
                status: "pending".to_string(),
            },
            ImageFlowStep {
                step_id: "generate".to_string(),
                step_name: "生成图片".to_string(),
                status: "pending".to_string(),
            },
        ],
        default_model: "dall-e-3".to_string(),
    }))
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ImageDefaultModelResponse {
    model: String,
    resolution: String,
}

pub(super) async fn post_edit_image_get_image_default_model(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<ImageDefaultModelResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    Ok(JsonResponse(ImageDefaultModelResponse {
        model: "dall-e-3".to_string(),
        resolution: "1024x1024".to_string(),
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct SaveImageFlowBody {
    #[allow(dead_code)]
    flow_id: String,
    #[allow(dead_code)]
    steps: Vec<ImageFlowStepInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ImageFlowStepInput {
    #[allow(dead_code)]
    step_id: String,
    #[allow(dead_code)]
    status: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct SaveImageFlowResponse {
    flow_id: String,
    saved: bool,
}

pub(super) async fn post_edit_image_save_image_flow(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SaveImageFlowBody>,
) -> Result<JsonResponse<SaveImageFlowResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    Ok(JsonResponse(SaveImageFlowResponse {
        flow_id: body.flow_id,
        saved: true,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct UpdateImageFlowBody {
    #[allow(dead_code)]
    flow_id: String,
    #[allow(dead_code)]
    step_id: String,
    #[allow(dead_code)]
    updates: serde_json::Value,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct UpdateImageFlowResponse {
    flow_id: String,
    step_id: String,
    updated: bool,
}

pub(super) async fn post_edit_image_update_image_flow(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateImageFlowBody>,
) -> Result<JsonResponse<UpdateImageFlowResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    Ok(JsonResponse(UpdateImageFlowResponse {
        flow_id: body.flow_id,
        step_id: body.step_id,
        updated: true,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct GenerateFlowImageBody {
    flow_id: String,
    prompt: String,
    #[serde(default)]
    model: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct GenerateFlowImageResponse {
    job_id: String,
    status: String,
}

pub(super) async fn post_edit_image_generate_flow_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateFlowImageBody>,
) -> Result<JsonResponse<GenerateFlowImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.flow_id.trim().is_empty() {
        return Err(ApiError::BadRequest("flowId must not be empty".into()));
    }
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let payload = serde_json::json!({
        "source": "production.edit-image.generate-flow",
        "flow_id": body.flow_id.trim(),
        "prompt": body.prompt.trim(),
        "model": body.model.unwrap_or_else(|| "dall-e-3".to_string()),
    });

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;

    Ok(JsonResponse(GenerateFlowImageResponse {
        job_id: row.id.to_string(),
        status: "queued".to_string(),
    }))
}
