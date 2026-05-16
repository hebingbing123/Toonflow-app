use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::{validate_non_empty_string, ApiError};
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::scope::http::require_script_write_scope_ref;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GenerateFlowImageBody {
    #[serde(default)]
    project_id: Option<i32>,
    #[serde(default)]
    project_uuid: Option<Uuid>,
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
    validate_non_empty_string(body.flow_id.trim(), "flowId")?;
    validate_non_empty_string(body.prompt.trim(), "prompt")?;
    let (uid, pool, scope_row) = require_script_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
    )
    .await?;

    let payload = serde_json::json!({
        "source": "production.edit-image.generate-flow",
        "project_uuid": scope_row.project_id,
        "project_numeric_id": scope_row.project_numeric_id,
        "script_id": body.script_id,
        "flow_id": body.flow_id.trim(),
        "prompt": body.prompt.trim(),
        "model": body.model.unwrap_or_else(|| "dall-e-3".to_string()),
    });

    let row = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_ASSET_GENERATE_BATCH,
        payload,
        Some(&headers),
        &state.billing_config,
    )
    .await?;

    Ok(JsonResponse(GenerateFlowImageResponse {
        job_id: row.id.to_string(),
        status: "queued".to_string(),
    }))
}
