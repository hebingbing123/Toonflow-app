//! 遗留 `POST …/upload-clip`。
//!
//! 上传片段端点。

use axum::{extract::State, http::HeaderMap, Json};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::models::*;
use super::super::{
    normalize_upload_clip_data_uri, ADV_LOCK_ASSET_IMAGE_LEGACY, ADV_LOCK_ASSET_LEGACY,
};

pub(crate) async fn post_legacy_upload_clip(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyUploadClipBody>,
) -> Result<Json<LegacyUploadClipResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
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

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2"#,
    )
    .bind(body.project_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_LEGACY)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_IMAGE_LEGACY)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_asset_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_image_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_image_id), 0) + 1 FROM app_asset_image"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let asset_id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO app_asset (
          project_id, legacy_id, name, asset_type, create_time_ms, metadata
        )
        VALUES (
          $1, $2, $3, 'clip', $4, jsonb_build_object('imageId', $5::integer)
        )
        RETURNING id
        "#,
    )
    .bind(project_uuid)
    .bind(next_asset_legacy)
    .bind(name)
    .bind(now_ms)
    .bind(next_image_legacy)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (
          asset_id, sort_index, file_path, state, legacy_image_id
        )
        VALUES ($1, 0, $2, '已完成', $3)
        "#,
    )
    .bind(asset_id)
    .bind(file_path)
    .bind(next_image_legacy)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyUploadClipResponse {
        message: "上传成功".into(),
    }))
}
