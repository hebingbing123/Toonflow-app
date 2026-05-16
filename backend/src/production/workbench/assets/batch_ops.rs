use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::state::AppState;

use super::common::{
    require_owned_normalized_assets_scope_ref, require_owned_normalized_assets_write_user_pool_ref,
};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct BatchGenerateAssetsImageBody {
    #[serde(default)]
    project_id: Option<i32>,
    #[serde(default)]
    project_uuid: Option<Uuid>,
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
    let (uid, pool, project_numeric_id) = require_owned_normalized_assets_write_user_pool_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        &body.asset_ids,
    )
    .await?;

    let default_model = body.model.as_deref().unwrap_or("dall-e-3");
    let default_resolution = body.resolution.as_deref().unwrap_or("1024x1024");

    let mut enqueued = Vec::with_capacity(body.asset_ids.len());
    for asset_id in &body.asset_ids {
        let payload = serde_json::json!({
            "source": "production.assets.batch-generate",
            "project_numeric_id": project_numeric_id,
            "script_id": body.script_id,
            "asset_id": asset_id,
            "model": default_model,
            "resolution": default_resolution,
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
    Ok(JsonResponse(BatchGenerateAssetsImageResponse {
        enqueued,
        total,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DeleteAssetsDerivativeBody {
    #[serde(default)]
    project_id: Option<i32>,
    #[serde(default)]
    project_uuid: Option<Uuid>,
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
    let (uid, pool, project_numeric_id, script_id, uniq) =
        require_owned_normalized_assets_scope_ref(
            &state,
            &headers,
            body.project_id,
            body.project_uuid,
            body.script_id,
            &body.asset_ids,
        )
        .await?;

    let result = sqlx::query(
        r#"
        DELETE FROM app_asset_image
        WHERE asset_id IN (
            SELECT a.id FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
            WHERE p.numeric_id = $2
              AND a.numeric_id = ANY($4::int4[])
              AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $1
              )
        )
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .bind(script_id)
    .bind(&uniq)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(DeleteAssetsDerivativeResponse {
        deleted: result.rows_affected() as i64,
        asset_ids: body.asset_ids,
    }))
}
