//! 分镜「单条添加 / 批量添加」HTTP 处理器。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::super::common::{insert_owned_storyboards_with_next_numeric_ids, require_pool};
use super::prepare::{prepare_batch_storyboard_inserts, prepare_storyboard_insert};
use super::types::{
    AddStoryboardBody, AddStoryboardResponse, BatchAddInfoBody, BatchAddInfoResponse,
};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/add",
    operation_id = "postProductionStoryboardAddV1",
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
pub(in crate::production) async fn post_storyboard_add(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddStoryboardBody>,
) -> Result<JsonResponse<AddStoryboardResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let prepared = prepare_storyboard_insert(&body.prompt, body.duration)?;

    let pool = require_pool(&state)?;
    let storyboard_ids = insert_owned_storyboards_with_next_numeric_ids(
        pool,
        uid,
        body.project_id,
        body.script_id,
        &[prepared],
    )
    .await?;
    let storyboard_id = storyboard_ids
        .into_iter()
        .next()
        .ok_or(ApiError::Internal)?;

    Ok(JsonResponse(AddStoryboardResponse {
        storyboard_id,
        message: "Storyboard added",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/batch-add-info",
    operation_id = "postProductionStoryboardBatchAddInfoV1",
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
pub(in crate::production) async fn post_storyboard_batch_add_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchAddInfoBody>,
) -> Result<JsonResponse<BatchAddInfoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let prepared_storyboards = prepare_batch_storyboard_inserts(&body.storyboards)?;

    let pool = require_pool(&state)?;
    let storyboard_ids = insert_owned_storyboards_with_next_numeric_ids(
        pool,
        uid,
        body.project_id,
        body.script_id,
        &prepared_storyboards,
    )
    .await?;

    Ok(JsonResponse(BatchAddInfoResponse {
        added: storyboard_ids.len(),
        storyboard_ids,
    }))
}
