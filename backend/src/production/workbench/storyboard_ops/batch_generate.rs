use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::common::{ensure_owned_storyboards, require_pool, require_positive_project_script_ids};
use super::types::{BatchGenerateImageBody, BatchGenerateImageResponse};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::scope;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/batch-generate-image",
    operation_id = "postProductionStoryboardBatchGenerateImageV1",
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
pub(in crate::production) async fn post_storyboard_batch_generate_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateImageBody>,
) -> Result<JsonResponse<BatchGenerateImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_project_script_ids(body.project_id, body.script_id)?;
    if body.items.is_empty() {
        return Err(ApiError::BadRequest("items must not be empty".into()));
    }

    let pool = require_pool(&state)?;
    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    if body.items.iter().any(|i| i.storyboard_id <= 0) {
        return Err(ApiError::BadRequest(
            "each item.storyboardId must be a positive integer".into(),
        ));
    }

    let mut uniq: Vec<i32> = body.items.iter().map(|i| i.storyboard_id).collect();
    uniq.sort_unstable();
    uniq.dedup();

    ensure_owned_storyboards(pool, scope_row.script_id, &uniq).await?;

    let default_model = body.model.as_deref().unwrap_or("dall-e-3");
    let default_resolution = body.resolution.as_deref().unwrap_or("1024x1024");

    let mut enqueued = Vec::with_capacity(body.items.len());
    for item in &body.items {
        let payload = serde_json::json!({
            "source": "production.storyboard.batch-generate-image",
            "project_numeric_id": body.project_id,
            "script_id": body.script_id,
            "storyboard_numeric_id": item.storyboard_id,
            "prompt": item.prompt,
            "negative_prompt": item.negative_prompt,
            "model": item.model.as_deref().unwrap_or(default_model),
            "resolution": item.resolution.as_deref().unwrap_or(default_resolution),
        });

        let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;
        enqueued.push(row);
    }

    let total = enqueued.len();
    Ok(JsonResponse(BatchGenerateImageResponse { enqueued, total }))
}
