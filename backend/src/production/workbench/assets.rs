use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::scope;
use crate::state::AppState;

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

pub(in crate::production) async fn post_assets_batch_generate_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateAssetsImageBody>,
) -> Result<JsonResponse<BatchGenerateAssetsImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    if body.asset_ids.is_empty() {
        return Err(ApiError::BadRequest("assetIds must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

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
    asset_ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DeleteAssetsDerivativeResponse {
    deleted: i64,
    asset_ids: Vec<i32>,
}

pub(in crate::production) async fn post_assets_delete_derivative(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteAssetsDerivativeBody>,
) -> Result<JsonResponse<DeleteAssetsDerivativeResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }
    if body.asset_ids.is_empty() {
        return Err(ApiError::BadRequest("assetIds must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Delete asset images (derivatives) for the given assets
    let result = sqlx::query(
        r#"
        DELETE FROM app_asset_image
        WHERE asset_id IN (
            SELECT a.id FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
              AND a.numeric_id = ANY($3::int4[])
        )
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(&body.asset_ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(DeleteAssetsDerivativeResponse {
        deleted: result.rows_affected() as i64,
        asset_ids: body.asset_ids,
    }))
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetDataItem {
    id: i32,
    name: String,
    #[serde(rename = "type")]
    asset_type: String,
    describe: Option<String>,
    cover_numeric_image_id: Option<i32>,
    created_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetsDataResponse {
    assets: Vec<AssetDataItem>,
    total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GetAssetsDataBody {
    project_id: i32,
    #[serde(default)]
    asset_type: Option<String>,
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default)]
    offset: Option<i64>,
}

pub(in crate::production) async fn post_assets_get_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetAssetsDataBody>,
) -> Result<JsonResponse<AssetsDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let limit = body.limit.map(|l| l.clamp(1, 100)).unwrap_or(50);
    let offset = body.offset.unwrap_or(0).max(0);

    let assets = sqlx::query_as::<_, AssetDataItem>(
        r#"
        SELECT
          a.numeric_id AS id,
          a.name,
          a.asset_type AS "type",
          a.describe,
          a.cover_numeric_image_id,
          a.created_at
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND ($3::text IS NULL OR a.asset_type = $3)
        ORDER BY a.created_at DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(
        body.asset_type
            .as_ref()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty()),
    )
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND ($3::text IS NULL OR a.asset_type = $3)
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(
        body.asset_type
            .as_ref()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty()),
    )
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(AssetsDataResponse { assets, total }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct AssetsPollingImageBody {
    project_id: i32,
    script_id: i32,
    asset_ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetImageStatus {
    asset_id: i32,
    image_count: i64,
    latest_state: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetsPollingImageResponse {
    statuses: Vec<AssetImageStatus>,
}

pub(in crate::production) async fn post_assets_polling_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AssetsPollingImageBody>,
) -> Result<JsonResponse<AssetsPollingImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    if body.asset_ids.is_empty() {
        return Err(ApiError::BadRequest("assetIds must not be empty".into()));
    }
    if body.asset_ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest(
            "assetIds must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let mut uniq = body.asset_ids.clone();
    uniq.sort_unstable();
    uniq.dedup();

    let statuses = sqlx::query_as::<_, AssetImageStatus>(
        r#"
        SELECT
          a.numeric_id AS asset_id,
          COUNT(ai.id) AS image_count,
          MAX(ai.state) AS latest_state
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $1
        LEFT JOIN app_asset_image ai ON ai.asset_id = a.id
        WHERE p.owner_user_id = $2
          AND p.numeric_id = $3
          AND a.numeric_id = ANY($4::int4[])
        GROUP BY a.numeric_id
        ORDER BY array_position($4::int4[], a.numeric_id)
        "#,
    )
    .bind(scope_row.script_id)
    .bind(uid)
    .bind(body.project_id)
    .bind(&uniq)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if statuses.len() != uniq.len() {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(AssetsPollingImageResponse { statuses }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct UpdateAssetsUrlBody {
    project_id: i32,
    asset_id: i32,
    image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateAssetsUrlResponse {
    asset_id: i32,
    image_url: String,
    message: &'static str,
}

pub(in crate::production) async fn post_assets_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateAssetsUrlBody>,
) -> Result<JsonResponse<UpdateAssetsUrlResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.asset_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and assetId must be positive integers".into(),
        ));
    }
    if body.image_url.trim().is_empty() {
        return Err(ApiError::BadRequest("imageUrl must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Insert new asset image with the provided URL
    let image_id = sqlx::query_scalar::<_, uuid::Uuid>(
        r#"
        INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
        SELECT $4, a.id, COALESCE(MAX(ai.sort_index), 0) + 1, $5, '已完成', '{}'::jsonb
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN app_asset_image ai ON ai.asset_id = a.id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.numeric_id = $3
        GROUP BY a.id
        RETURNING id
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.asset_id)
    .bind(uuid::Uuid::new_v4())
    .bind(body.image_url.trim())
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if image_id.is_none() {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(UpdateAssetsUrlResponse {
        asset_id: body.asset_id,
        image_url: body.image_url.trim().to_string(),
        message: "Asset image URL updated",
    }))
}
