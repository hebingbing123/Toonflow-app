//! 批量生成候选分页（**`POST …/assets/workbench/batch-generation-data`**）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::ensure_owned_project_numeric_id;
use super::super::models::*;
use super::super::utils::{normalize_name_ilike, MAX_ASSET_LIST_LIMIT};

async fn run_batch_generation_data(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_numeric_id: i32,
    body: &WorkbenchBatchGenerationDataBody,
) -> Result<WorkbenchBatchGenerationDataResponse, ApiError> {
    let asset_type = body.asset_type.trim().to_lowercase();
    let name = normalize_name_ilike(body.name.clone());

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.asset_type = $3
          AND ($4::text IS NULL OR a.name ILIKE $4)
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .bind(&asset_type)
    .bind(name.as_deref())
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let offset = (body.page - 1) as i64 * body.limit as i64;
    let data: Vec<WorkbenchBatchGenerationAssetItem> = sqlx::query_as(
        r#"
        SELECT
          a.numeric_id AS id,
          a.name AS name,
          a.asset_type AS asset_type,
          a.description AS description,
          a.create_time_ms AS create_time_ms
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.asset_type = $3
          AND ($4::text IS NULL OR a.name ILIKE $4)
        ORDER BY a.create_time_ms DESC NULLS LAST, a.numeric_id DESC
        OFFSET $5
        LIMIT $6
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .bind(asset_type)
    .bind(name.as_deref())
    .bind(offset)
    .bind(body.limit as i64)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(WorkbenchBatchGenerationDataResponse { data, total })
}

pub(crate) async fn post_project_workbench_batch_generation_data(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchBatchGenerationDataBody>,
) -> Result<Json<WorkbenchBatchGenerationDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
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
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let project_numeric_id = ensure_owned_project_numeric_id(pool, uid, project_id).await?;
    let out = run_batch_generation_data(pool, uid, project_numeric_id, &body).await?;
    Ok(Json(out))
}
