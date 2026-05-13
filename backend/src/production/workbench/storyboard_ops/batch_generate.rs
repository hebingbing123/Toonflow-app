use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::common::{normalize_storyboard_ids, require_owned_normalized_storyboards_user_pool_ref};
use super::types::{BatchGenerateImageBody, BatchGenerateImageResponse};
use crate::error::{bad_request_i18n, ApiError};
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
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
    if body.items.is_empty() {
        return Err(bad_request_i18n(
            "items must not be empty",
            "items 不能为空",
        ));
    }

    let normalized_ids = normalize_batch_generate_storyboard_ids(&body.items)?;
    let (uid, pool, project_numeric_id) = require_owned_normalized_storyboards_user_pool_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        &normalized_ids,
    )
    .await?;

    let default_model = body.model.as_deref().unwrap_or("dall-e-3");
    let default_resolution = body.resolution.as_deref().unwrap_or("1024x1024");

    let mut enqueued = Vec::with_capacity(body.items.len());
    for item in &body.items {
        let payload = serde_json::json!({
            "source": "production.storyboard.batch-generate-image",
            "project_numeric_id": project_numeric_id,
            "script_id": body.script_id,
            "storyboard_numeric_id": item.storyboard_id,
            "prompt": item.prompt,
            "negative_prompt": item.negative_prompt,
            "model": item.model.as_deref().unwrap_or(default_model),
            "resolution": item.resolution.as_deref().unwrap_or(default_resolution),
        });
        let payload = if let Some(project_uuid) = body.project_uuid {
            let mut payload = payload;
            payload["project_uuid"] = serde_json::json!(project_uuid);
            payload
        } else {
            payload
        };

        let row = enqueue_generation_job(
            pool,
            uid,
            JOB_KIND_ASSET_GENERATE_BATCH,
            payload,
            Some(&headers),
            &state.billing_config,
        )
        .await?;
        enqueued.push(row);
    }

    let total = enqueued.len();
    Ok(JsonResponse(BatchGenerateImageResponse { enqueued, total }))
}

fn normalize_batch_generate_storyboard_ids(
    items: &[super::types::BatchGenerateImageItem],
) -> Result<Vec<i32>, ApiError> {
    let storyboard_ids: Vec<i32> = items.iter().map(|item| item.storyboard_id).collect();
    if storyboard_ids.iter().any(|id| *id <= 0) {
        return Err(bad_request_i18n(
            "each item.storyboardId must be a positive integer",
            "每个 item.storyboardId 都必须是正整数",
        ));
    }

    normalize_storyboard_ids(&storyboard_ids)
}

#[cfg(test)]
mod tests {
    use super::normalize_batch_generate_storyboard_ids;
    use crate::error::ApiError;
    use crate::production::workbench::storyboard_ops::types::BatchGenerateImageItem;

    #[test]
    fn normalize_batch_generate_storyboard_ids_rejects_non_positive_values() {
        let err = normalize_batch_generate_storyboard_ids(&[BatchGenerateImageItem {
            storyboard_id: 0,
            prompt: "prompt".into(),
            negative_prompt: None,
            model: None,
            resolution: None,
        }])
        .unwrap_err();
        assert!(
            matches!(err, ApiError::BadRequest(message) if message == "each item.storyboardId must be a positive integer")
        );
    }

    #[test]
    fn normalize_batch_generate_storyboard_ids_sorts_and_deduplicates() {
        let ids = normalize_batch_generate_storyboard_ids(&[
            BatchGenerateImageItem {
                storyboard_id: 4,
                prompt: "four".into(),
                negative_prompt: None,
                model: None,
                resolution: None,
            },
            BatchGenerateImageItem {
                storyboard_id: 2,
                prompt: "two".into(),
                negative_prompt: None,
                model: None,
                resolution: None,
            },
            BatchGenerateImageItem {
                storyboard_id: 4,
                prompt: "duplicate".into(),
                negative_prompt: None,
                model: None,
                resolution: None,
            },
        ])
        .unwrap();

        assert_eq!(ids, vec![2, 4]);
    }
}
