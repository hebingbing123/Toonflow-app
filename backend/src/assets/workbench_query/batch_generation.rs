//! 批量生成候选分页（**`POST …/assets/workbench/batch-generation-data`**）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::state::AppState;

use super::super::crud::require_asset_project_read_scope;
use super::super::models::*;
use super::super::utils::{normalize_name_ilike, MAX_ASSET_LIST_LIMIT};

async fn run_batch_generation_data(
    pool: &sqlx::PgPool,
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
        WHERE p.numeric_id = $1
          AND a.asset_type = $2
          AND ($3::text IS NULL OR a.name ILIKE $3)
        "#,
    )
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
        WHERE p.numeric_id = $1
          AND a.asset_type = $2
          AND ($3::text IS NULL OR a.name ILIKE $3)
        ORDER BY a.create_time_ms DESC NULLS LAST, a.numeric_id DESC
        OFFSET $4
        LIMIT $5
        "#,
    )
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
        return Err(bad_request_i18n("type must be non-empty", "type 不能为空"));
    }
    if body.page < 1 {
        return Err(bad_request_i18n("page must be >= 1", "page 必须大于等于 1"));
    }
    if body.limit < 1 || body.limit > MAX_ASSET_LIST_LIMIT as i32 {
        return Err(bad_request_i18n(
            &format!("limit must be between 1 and {MAX_ASSET_LIST_LIMIT}"),
            &format!("limit 必须在 1 到 {MAX_ASSET_LIST_LIMIT} 之间"),
        ));
    }
    let pool = state.require_pool()?;
    require_asset_project_read_scope(&state, uid, project_id).await?;
    let project_numeric_id: i32 =
        sqlx::query_scalar("SELECT numeric_id FROM app_project WHERE id = $1")
            .bind(project_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let out = run_batch_generation_data(pool, project_numeric_id, &body).await?;
    Ok(Json(out))
}
