use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::scope::http::require_owned_numeric_script_scope_user_pool;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GenerateFlowImageBody {
    project_id: i32,
    script_id: i32,
    flow_id: String,
    prompt: String,
    #[serde(default)]
    model: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GenerateFlowImageResponse {
    job_id: String,
    status: String,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/edit-image/generate-flow-image",
    operation_id = "postProductionEditImageGenerateFlowImageV1",
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
pub(in crate::production) async fn post_edit_image_generate_flow_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateFlowImageBody>,
) -> Result<JsonResponse<GenerateFlowImageResponse>, ApiError> {
    if body.flow_id.trim().is_empty() {
        return Err(ApiError::BadRequest("flowId must not be empty".into()));
    }
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }
    let (uid, pool) = require_owned_numeric_script_scope_user_pool(
        &state,
        &headers,
        body.project_id,
        body.script_id,
    )
    .await?;

    let payload = serde_json::json!({
        "source": "production.edit-image.generate-flow",
        "project_numeric_id": body.project_id,
        "script_id": body.script_id,
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
