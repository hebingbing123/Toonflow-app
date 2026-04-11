//! 遗留 `POST …/batch-generation-data` — 批量生成数据查询。
//!
//! 返回适合批量生成工作流的资产分页列表。

use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::models::*;
use super::super::{normalize_name_ilike, MAX_ASSET_LIST_LIMIT};

pub(crate) async fn post_legacy_batch_generation_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyBatchGenerationDataBody>,
) -> Result<Json<LegacyBatchGenerationDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    let asset_type = body.asset_type.trim().to_lowercase();
    if asset_type.is_empty() {
        return Err(ApiError::BadRequest("type must be non-empty".into()));
    }
    if body.page < 1 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if body.limit < 1 || body.limit > MAX_ASSET_LIST_LIMIT as i32 {
        return Err(ApiError::BadRequest(format!(
            "limit must be between 1 and {MAX_ASSET_LIST_LIMIT}"
        )));
    }
    let name = normalize_name_ilike(body.name);

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.asset_type = $3
          AND ($4::text IS NULL OR a.name ILIKE $4)
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(&asset_type)
    .bind(name.as_deref())
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let offset = (body.page - 1) as i64 * body.limit as i64;
    let data: Vec<LegacyBatchGenerationAssetItem> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          a.name AS name,
          a.asset_type AS asset_type,
          a.description AS description,
          a.create_time_ms AS create_time_ms
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.asset_type = $3
          AND ($4::text IS NULL OR a.name ILIKE $4)
        ORDER BY a.create_time_ms DESC NULLS LAST, a.legacy_id DESC
        OFFSET $5
        LIMIT $6
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(asset_type)
    .bind(name.as_deref())
    .bind(offset)
    .bind(body.limit as i64)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyBatchGenerationDataResponse { data, total }))
}
