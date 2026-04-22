//! 分镜编辑、删帧、更新图片 URL。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::super::common::{
    normalize_storyboard_image_url, normalize_storyboard_prompt, remove_storyboard_frame,
    update_storyboard_image_url, update_storyboard_info, validate_storyboard_duration,
};
use super::types::{
    EditStoryboardInfoBody, EditStoryboardInfoResponse, RemoveFrameBody, RemoveFrameResponse,
    UpdateStoryboardUrlBody, UpdateStoryboardUrlResponse,
};
use crate::error::ApiError;
use crate::scope::http::require_owned_numeric_storyboard_scope;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/edit-info",
    operation_id = "postProductionStoryboardEditInfoV1",
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
pub(in crate::production) async fn post_storyboard_edit_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditStoryboardInfoBody>,
) -> Result<JsonResponse<EditStoryboardInfoResponse>, ApiError> {
    let prompt = normalize_storyboard_prompt(&body.prompt)?;
    let duration = validate_storyboard_duration(body.duration)?;

    let (pool, sb_uuid) = require_owned_numeric_storyboard_scope(
        &state,
        &headers,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    update_storyboard_info(pool, sb_uuid, &prompt, duration).await?;

    Ok(JsonResponse(EditStoryboardInfoResponse {
        storyboard_id: body.storyboard_id,
        message: "Storyboard info updated",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/remove-frame",
    operation_id = "postProductionStoryboardRemoveFrameV1",
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
pub(in crate::production) async fn post_storyboard_remove_frame(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<RemoveFrameBody>,
) -> Result<JsonResponse<RemoveFrameResponse>, ApiError> {
    let (pool, sb_uuid) = require_owned_numeric_storyboard_scope(
        &state,
        &headers,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    remove_storyboard_frame(pool, sb_uuid).await?;

    Ok(JsonResponse(RemoveFrameResponse {
        storyboard_id: body.storyboard_id,
        message: "Frame removed from storyboard",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/update-url",
    operation_id = "postProductionStoryboardUpdateUrlV1",
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
pub(in crate::production) async fn post_storyboard_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardUrlBody>,
) -> Result<JsonResponse<UpdateStoryboardUrlResponse>, ApiError> {
    let image_url = normalize_storyboard_image_url(&body.image_url)?;

    let (pool, sb_uuid) = require_owned_numeric_storyboard_scope(
        &state,
        &headers,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    update_storyboard_image_url(pool, sb_uuid, &image_url).await?;

    Ok(JsonResponse(UpdateStoryboardUrlResponse {
        storyboard_id: body.storyboard_id,
        image_url,
        message: "Storyboard image URL updated",
    }))
}
