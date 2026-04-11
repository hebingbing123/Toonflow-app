//! 资产变更辅助端点（**`POST …/projects/{project_id}/assets/workbench/*`**）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde_json::Value;
use sqlx::types::Json as SqlxJson;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::crud::ensure_owned_project_pk;
use super::models::*;
use super::{
    merge_legacy_asset_metadata, normalize_upload_clip_data_uri, resolve_owned_asset_metadata,
    ADV_LOCK_ASSET_IMAGE_NUMERIC, ADV_LOCK_ASSET_NUMERIC,
};

pub(super) async fn post_project_workbench_add_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchAddAssetsBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }
    let describe = body.describe.trim();
    if describe.is_empty() {
        return Err(ApiError::BadRequest("describe must not be empty".into()));
    }
    let asset_type = body.asset_type.trim().to_lowercase();
    if asset_type != "role" && asset_type != "scene" && asset_type != "tool" {
        return Err(ApiError::BadRequest(
            "type must be role, scene, or tool".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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

    let next_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let metadata = merge_legacy_asset_metadata(
        Value::Object(Default::default()),
        Some(super::normalize_optional_legacy_text(body.prompt)),
        Some(super::normalize_optional_legacy_text(body.remark)),
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
    .bind(next_legacy)
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

    Ok(Json(LegacyAssetMutationResponse {
        message: "新增资产成功",
    }))
}

pub(super) async fn post_project_workbench_update_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<LegacyUpdateAssetsBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }
    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }
    let describe = body.describe.trim();
    if describe.is_empty() {
        return Err(ApiError::BadRequest("describe must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let current = resolve_owned_asset_metadata(pool, uid, body.id).await?;
    let metadata = merge_legacy_asset_metadata(
        current.metadata.0,
        Some(super::normalize_optional_legacy_text(body.prompt)),
        Some(super::normalize_optional_legacy_text(body.remark)),
        None,
    );

    sqlx::query(
        r#"
        UPDATE app_asset a
        SET name = $1,
            description = $2,
            metadata = $3,
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $4
          AND p.id = $5
          AND a.numeric_id = $6
        "#,
    )
    .bind(name)
    .bind(describe)
    .bind(SqlxJson(metadata))
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "更新资产成功",
    }))
}

pub(super) async fn post_project_workbench_save_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchSaveAssetsBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }
    let asset_type = body.asset_type.trim().to_lowercase();
    if asset_type != "role" && asset_type != "scene" && asset_type != "tool" {
        return Err(ApiError::BadRequest(
            "type must be role, scene, or tool".into(),
        ));
    }
    if body.image_id.is_some_and(|id| id <= 0) {
        return Err(ApiError::BadRequest(
            "imageId must be positive when set".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let current: LegacyOwnedAssetMetaRow = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let mut image_patch = body.image_id;
    if let Some(raw_base64) = body
        .base64
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
    {
        let file_path = normalize_upload_clip_data_uri(raw_base64)?;
        sqlx::query("SELECT pg_advisory_xact_lock($1)")
            .bind(ADV_LOCK_ASSET_IMAGE_NUMERIC)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let next_image_legacy: i32 = sqlx::query_scalar(
            r#"SELECT COALESCE(MAX(numeric_image_id), 0) + 1 FROM app_asset_image"#,
        )
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let next_sort: i32 = sqlx::query_scalar(
            r#"
            SELECT COALESCE(MAX(sort_index), -1) + 1
            FROM app_asset_image
            WHERE asset_id = $1
            "#,
        )
        .bind(current.id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        sqlx::query(
            r#"
            INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, numeric_image_id)
            VALUES ($1, $2, $3, '已完成', $4)
            "#,
        )
        .bind(current.id)
        .bind(next_sort)
        .bind(file_path)
        .bind(next_image_legacy)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        image_patch = Some(next_image_legacy);
    }

    let metadata = merge_legacy_asset_metadata(
        current.metadata.0,
        Some(super::normalize_optional_legacy_text(body.prompt)),
        None,
        Some(image_patch),
    );

    sqlx::query(
        r#"
        UPDATE app_asset a
        SET metadata = $1,
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $2
          AND p.id = $3
          AND a.numeric_id = $4
        "#,
    )
    .bind(SqlxJson(metadata))
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "保存资产图片成功",
    }))
}

pub(super) async fn post_project_workbench_del_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<LegacyDeleteAssetsBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "删除资产成功",
    }))
}

pub(super) async fn post_project_workbench_batch_delete_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<LegacyBatchDeleteAssetsBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id.is_empty() {
        return Err(ApiError::BadRequest("id must not be empty".into()));
    }
    if body.id.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("id entries must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND a.numeric_id = ANY($3)
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(&body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "删除资产成功",
    }))
}

pub(super) async fn post_project_workbench_del_image(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<LegacyDelImageBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    sqlx::query(
        r#"
        UPDATE app_asset a
        SET metadata = a.metadata - 'imageId',
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
          AND (a.metadata->>'imageId')::integer = $3
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_asset_image ai
        USING app_asset a, app_project p
        WHERE ai.asset_id = a.id
          AND a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND ai.numeric_image_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "资产图片删除成功",
    }))
}
