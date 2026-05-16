use axum::{extract::State, http::HeaderMap, Json as JsonResponse};

use crate::error::ApiError;
use crate::scope::http::require_authenticated;
use crate::state::AppState;

use super::types::{ImageFlowResponse, ImageFlowStep};

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
    require_authenticated(&state, &headers)?;

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
