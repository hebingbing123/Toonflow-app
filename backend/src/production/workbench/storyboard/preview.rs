use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::common::{
    build_down_preview_image_response, build_preview_image_response,
    fetch_owned_storyboard_preview_data, require_pool, DownPreviewImageResponse,
    PreviewImageResponse, StoryboardScopeBody,
};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/down-preview-image",
    operation_id = "postProductionStoryboardDownPreviewImageV1",
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
pub(in crate::production) async fn post_storyboard_down_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardScopeBody>,
) -> Result<JsonResponse<DownPreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    let pool = require_pool(&state)?;
    let preview = fetch_owned_storyboard_preview_data(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    Ok(JsonResponse(build_down_preview_image_response(
        body.storyboard_id,
        preview,
    )?))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/preview-image",
    operation_id = "postProductionStoryboardPreviewImageV1",
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
pub(in crate::production) async fn post_storyboard_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardScopeBody>,
) -> Result<JsonResponse<PreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    let pool = require_pool(&state)?;
    let preview = fetch_owned_storyboard_preview_data(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    Ok(JsonResponse(build_preview_image_response(
        body.storyboard_id,
        preview,
    )))
}
