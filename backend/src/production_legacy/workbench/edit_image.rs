use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use base64::Engine;
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::state::AppState;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct ImageFlowResponse {
    flow_id: String,
    steps: Vec<ImageFlowStep>,
    default_model: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct ImageFlowStep {
    step_id: String,
    step_name: String,
    status: String,
}

pub(in crate::production_legacy) async fn post_edit_image_get_image_flow(
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
pub(in crate::production_legacy) struct ImageDefaultModelResponse {
    model: String,
    resolution: String,
}

pub(in crate::production_legacy) async fn post_edit_image_get_image_default_model(
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
pub(in crate::production_legacy) struct SaveImageFlowBody {
    #[allow(dead_code)]
    flow_id: String,
    #[allow(dead_code)]
    steps: Vec<ImageFlowStepInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct ImageFlowStepInput {
    #[allow(dead_code)]
    step_id: String,
    #[allow(dead_code)]
    status: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct SaveImageFlowResponse {
    flow_id: String,
    saved: bool,
}

pub(in crate::production_legacy) async fn post_edit_image_save_image_flow(
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
pub(in crate::production_legacy) struct UpdateImageFlowBody {
    #[allow(dead_code)]
    flow_id: String,
    #[allow(dead_code)]
    step_id: String,
    #[allow(dead_code)]
    updates: serde_json::Value,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct UpdateImageFlowResponse {
    flow_id: String,
    step_id: String,
    updated: bool,
}

pub(in crate::production_legacy) async fn post_edit_image_update_image_flow(
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
pub(in crate::production_legacy) struct EditImageUploadImageBody {
    project_id: i32,
    script_id: i32,
    base64_data: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct EditImageUploadImageResponse {
    url: String,
}

fn normalize_upload_image_data_uri(input: &str) -> Result<String, ApiError> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return Err(ApiError::BadRequest("base64Data must not be empty".into()));
    }
    let (prefix, payload) = trimmed
        .split_once(',')
        .ok_or_else(|| ApiError::BadRequest("base64Data must be a valid data URI".into()))?;
    let lower = prefix.to_ascii_lowercase();
    if !(lower.starts_with("data:image/jpeg;")
        || lower.starts_with("data:image/jpg;")
        || lower.starts_with("data:image/png;"))
        || !lower.contains(";base64")
    {
        return Err(ApiError::BadRequest("不支持的文件类型".into()));
    }

    let payload = payload.trim();
    if payload.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }
    base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| ApiError::BadRequest("base64Data must be valid base64".into()))?;

    let mime = prefix
        .trim()
        .strip_prefix("data:")
        .and_then(|s| s.split(';').next())
        .unwrap_or("image/png")
        .to_ascii_lowercase();
    Ok(format!("data:{mime};base64,{payload}"))
}

pub(in crate::production_legacy) async fn post_edit_image_upload_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditImageUploadImageBody>,
) -> Result<JsonResponse<EditImageUploadImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be > 0".into()));
    }
    if body.script_id <= 0 {
        return Err(ApiError::BadRequest("scriptId must be > 0".into()));
    }
    let normalized = normalize_upload_image_data_uri(&body.base64_data)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    super::flow::resolve_owned_production_scope(pool, uid, body.project_id, body.script_id).await?;

    Ok(JsonResponse(EditImageUploadImageResponse {
        url: normalized,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production_legacy) struct GenerateFlowImageBody {
    flow_id: String,
    prompt: String,
    #[serde(default)]
    model: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct GenerateFlowImageResponse {
    job_id: String,
    status: String,
}

pub(in crate::production_legacy) async fn post_edit_image_generate_flow_image(
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

#[cfg(test)]
mod tests {
    use super::normalize_upload_image_data_uri;
    use crate::error::ApiError;

    #[test]
    fn upload_image_normalize_accepts_png_data_uri() {
        let got = normalize_upload_image_data_uri("data:image/png;base64,AA==").expect("png");
        assert_eq!(got, "data:image/png;base64,AA==");
    }

    #[test]
    fn upload_image_normalize_rejects_non_image_mime() {
        let err = normalize_upload_image_data_uri("data:text/plain;base64,AA==")
            .expect_err("text mime should fail");
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains("不支持")),
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn upload_image_normalize_rejects_invalid_base64() {
        let err = normalize_upload_image_data_uri("data:image/png;base64,not-base64")
            .expect_err("invalid base64");
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains("valid base64")),
            other => panic!("unexpected error: {other:?}"),
        }
    }
}
