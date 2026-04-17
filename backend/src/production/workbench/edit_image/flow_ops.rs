use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ImageFlowResponse {
    flow_id: String,
    steps: Vec<ImageFlowStep>,
    default_model: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ImageFlowStep {
    step_id: String,
    step_name: String,
    status: String,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/edit-image/get-image-flow",
    operation_id = "postProductionEditImageGetFlowV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_edit_image_get_image_flow(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<ImageFlowResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

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
pub(in crate::production) struct ImageDefaultModelResponse {
    model: String,
    resolution: String,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/edit-image/get-image-default-model",
    operation_id = "postProductionEditImageGetDefaultModelV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_edit_image_get_image_default_model(
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
pub(in crate::production) struct SaveImageFlowBody {
    flow_id: String,
    #[allow(dead_code)]
    steps: Vec<ImageFlowStepInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ImageFlowStepInput {
    #[allow(dead_code)]
    step_id: String,
    #[allow(dead_code)]
    status: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct SaveImageFlowResponse {
    flow_id: String,
    saved: bool,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/edit-image/save-image-flow",
    operation_id = "postProductionEditImageSaveFlowV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_edit_image_save_image_flow(
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
pub(in crate::production) struct UpdateImageFlowBody {
    flow_id: String,
    step_id: String,
    #[allow(dead_code)]
    updates: serde_json::Value,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateImageFlowResponse {
    flow_id: String,
    step_id: String,
    updated: bool,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/edit-image/update-image-flow",
    operation_id = "postProductionEditImageUpdateFlowV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_edit_image_update_image_flow(
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
