//! Clip 资产上传（**`POST …/assets/workbench/upload-clip`**）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::ensure_owned_project_pk;
use super::super::models::*;
use super::super::utils::{normalize_upload_clip_data_uri, ADV_LOCK_ASSET_IMAGE_NUMERIC};
use super::super::ADV_LOCK_ASSET_NUMERIC;

pub(crate) async fn post_project_workbench_upload_clip(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchUploadClipBody>,
) -> Result<Json<WorkbenchUploadClipResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let asset_type = body
        .asset_type
        .as_deref()
        .unwrap_or("clip")
        .trim()
        .to_lowercase();
    if asset_type != "clip" {
        return Err(ApiError::BadRequest("type must be clip".into()));
    }

    let file_path = normalize_upload_clip_data_uri(&body.base64_data)?;

    let pool = state.require_pool()?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_IMAGE_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_asset_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_image_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_image_id), 0) + 1 FROM app_asset_image"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let asset_id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO app_asset (
          project_id, numeric_id, name, asset_type, create_time_ms, metadata
        )
        VALUES (
          $1, $2, $3, 'clip', $4, jsonb_build_object('imageId', $5::integer)
        )
        RETURNING id
        "#,
    )
    .bind(project_id)
    .bind(next_asset_numeric_id)
    .bind(name)
    .bind(now_ms)
    .bind(next_image_numeric_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (
          asset_id, sort_index, file_path, state, numeric_image_id
        )
        VALUES ($1, 0, $2, '已完成', $3)
        "#,
    )
    .bind(asset_id)
    .bind(file_path)
    .bind(next_image_numeric_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchUploadClipResponse {
        message: "上传成功".into(),
    }))
}
