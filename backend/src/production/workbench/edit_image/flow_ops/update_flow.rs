use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::types::{UpdateImageFlowBody, UpdateImageFlowResponse};

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
