use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::state::AppState;

use super::common::{
    ensure_assets_linked_to_script, normalize_asset_ids, require_owned_script_scope,
    validate_project_and_script_ids,
};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct BatchGenerateAssetsImageBody {
    project_id: i32,
    script_id: i32,
    asset_ids: Vec<i32>,
    #[serde(default)]
    model: Option<String>,
    #[serde(default)]
    resolution: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct BatchGenerateAssetsImageResponse {
    enqueued: Vec<JobRow>,
    total: usize,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/assets/batch-generate-assets-image",
    operation_id = "postProductionAssetsBatchGenerateImageV1",
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
pub(in crate::production) async fn post_assets_batch_generate_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateAssetsImageBody>,
) -> Result<JsonResponse<BatchGenerateAssetsImageResponse>, ApiError> {
    validate_project_and_script_ids(body.project_id, body.script_id)?;
    let uniq = normalize_asset_ids(&body.asset_ids)?;
    let (uid, pool, scope_row) =
        require_owned_script_scope(&state, &headers, body.project_id, body.script_id).await?;
    ensure_assets_linked_to_script(pool, uid, body.project_id, scope_row.script_id, &uniq).await?;

    let default_model = body.model.as_deref().unwrap_or("dall-e-3");
    let default_resolution = body.resolution.as_deref().unwrap_or("1024x1024");

    let mut enqueued = Vec::with_capacity(body.asset_ids.len());
    for asset_id in &body.asset_ids {
        let payload = serde_json::json!({
            "source": "production.assets.batch-generate",
            "project_numeric_id": body.project_id,
            "script_id": body.script_id,
            "asset_id": asset_id,
            "model": default_model,
            "resolution": default_resolution,
        });

        let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;
        enqueued.push(row);
    }

    let total = enqueued.len();
    Ok(JsonResponse(BatchGenerateAssetsImageResponse {
        enqueued,
        total,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DeleteAssetsDerivativeBody {
    project_id: i32,
    script_id: i32,
    asset_ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DeleteAssetsDerivativeResponse {
    deleted: i64,
    asset_ids: Vec<i32>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/assets/delete-assets-derivative",
    operation_id = "postProductionAssetsDeleteDerivativeV1",
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
pub(in crate::production) async fn post_assets_delete_derivative(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteAssetsDerivativeBody>,
) -> Result<JsonResponse<DeleteAssetsDerivativeResponse>, ApiError> {
    validate_project_and_script_ids(body.project_id, body.script_id)?;
    let uniq = normalize_asset_ids(&body.asset_ids)?;
    let (uid, pool, scope_row) =
        require_owned_script_scope(&state, &headers, body.project_id, body.script_id).await?;
    ensure_assets_linked_to_script(pool, uid, body.project_id, scope_row.script_id, &uniq).await?;

    let result = sqlx::query(
        r#"
        DELETE FROM app_asset_image
        WHERE asset_id IN (
            SELECT a.id FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
              AND a.numeric_id = ANY($4::int4[])
        )
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(scope_row.script_id)
    .bind(&uniq)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(DeleteAssetsDerivativeResponse {
        deleted: result.rows_affected() as i64,
        asset_ids: body.asset_ids,
    }))
}
