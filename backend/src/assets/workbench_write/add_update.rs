use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde_json::Value;
use sqlx::types::Json as SqlxJson;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_enum, validate_non_empty_string, validate_positive, ApiError};
use crate::state::AppState;

use super::super::crud::require_asset_project_write_scope;
use super::super::models::*;
use super::super::utils::{
    merge_workbench_asset_metadata, normalize_optional_trimmed_text, resolve_owned_asset_metadata,
};
use super::super::ADV_LOCK_ASSET_NUMERIC;

pub(crate) async fn post_project_workbench_add_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchAddAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let name = body.name.trim();
    validate_non_empty_string(name, "name")?;
    let describe = body.describe.trim();
    validate_non_empty_string(describe, "describe")?;
    let asset_type = body.asset_type.trim().to_lowercase();
    validate_enum(&asset_type, &["role", "scene", "tool"], "type")?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let metadata = merge_workbench_asset_metadata(
        Value::Object(Default::default()),
        Some(normalize_optional_trimmed_text(body.prompt)),
        Some(normalize_optional_trimmed_text(body.remark)),
        None,
    );

    sqlx::query(
        r#"
        INSERT INTO app_asset (
          project_id, numeric_id, name, asset_type, description, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(project_id)
    .bind(next_numeric_id)
    .bind(name)
    .bind(asset_type)
    .bind(describe)
    .bind(now_ms)
    .bind(SqlxJson(metadata))
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchAssetMutationResponse {
        message: "新增资产成功",
    }))
}

pub(crate) async fn post_project_workbench_update_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchUpdateAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(body.id, "id")?;
    let name = body.name.trim();
    validate_non_empty_string(name, "name")?;
    let describe = body.describe.trim();
    validate_non_empty_string(describe, "describe")?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    let current = resolve_owned_asset_metadata(pool, uid, project_id, body.id).await?;
    let metadata = merge_workbench_asset_metadata(
        current.metadata.0,
        Some(normalize_optional_trimmed_text(body.prompt)),
        Some(normalize_optional_trimmed_text(body.remark)),
        None,
    );

    sqlx::query(
        r#"
        UPDATE app_asset
        SET name = $1,
            description = $2,
            metadata = $3,
            updated_at = NOW()
        WHERE project_id = $4
          AND numeric_id = $5
        "#,
    )
    .bind(name)
    .bind(describe)
    .bind(SqlxJson(metadata))
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchAssetMutationResponse {
        message: "更新资产成功",
    }))
}
