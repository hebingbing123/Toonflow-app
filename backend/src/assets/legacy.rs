//! Legacy POST asset operations (add/update/save/del/get-image/upload-clip/material/polling).

use axum::{extract::State, http::HeaderMap, Json};
use serde_json::Value;
use sqlx::types::Json as SqlxJson;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::models::*;
use super::{
    merge_legacy_asset_metadata, normalize_name_ilike, normalize_upload_clip_data_uri,
    resolve_owned_asset_metadata, ADV_LOCK_ASSET_IMAGE_LEGACY, ADV_LOCK_ASSET_LEGACY,
    MAX_ASSET_LIST_LIMIT,
};

pub(super) async fn post_legacy_add_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyAddAssetsBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
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

    let next_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_asset"#)
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
          project_id, legacy_id, name, asset_type, description, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(project_uuid)
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

pub(super) async fn post_legacy_update_assets(
    State(state): State<AppState>,
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
          AND a.legacy_id = $5
        "#,
    )
    .bind(name)
    .bind(describe)
    .bind(SqlxJson(metadata))
    .bind(uid)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "更新资产成功",
    }))
}

pub(super) async fn post_legacy_save_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacySaveAssetsBody>,
) -> Result<Json<LegacyAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
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

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let current: LegacyOwnedAssetMetaRow = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata, p.legacy_id AS project_legacy_id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND a.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;
    if current.project_legacy_id != body.project_id {
        tx.rollback().await.ok();
        return Err(ApiError::NotFound);
    }

    let mut image_patch = body.image_id;
    if let Some(raw_base64) = body
        .base64
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
    {
        let file_path = normalize_upload_clip_data_uri(raw_base64)?;
        sqlx::query("SELECT pg_advisory_xact_lock($1)")
            .bind(ADV_LOCK_ASSET_IMAGE_LEGACY)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let next_image_legacy: i32 = sqlx::query_scalar(
            r#"SELECT COALESCE(MAX(legacy_image_id), 0) + 1 FROM app_asset_image"#,
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
            INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, legacy_image_id)
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
          AND p.legacy_id = $3
          AND a.legacy_id = $4
        "#,
    )
    .bind(SqlxJson(metadata))
    .bind(uid)
    .bind(body.project_id)
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

pub(super) async fn post_legacy_del_assets(
    State(state): State<AppState>,
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

    sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND a.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "删除资产成功",
    }))
}

pub(super) async fn post_legacy_batch_delete_assets(
    State(state): State<AppState>,
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

    sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND a.legacy_id = ANY($2)
        "#,
    )
    .bind(uid)
    .bind(&body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "删除资产成功",
    }))
}

pub(super) async fn post_legacy_del_image(
    State(state): State<AppState>,
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

    sqlx::query(
        r#"
        UPDATE app_asset a
        SET metadata = a.metadata - 'imageId',
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
          AND (a.metadata->>'imageId')::integer = $2
        "#,
    )
    .bind(uid)
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
          AND ai.legacy_image_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyAssetMutationResponse {
        message: "资产图片删除成功",
    }))
}

pub(super) async fn post_legacy_get_assets_api(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyGetAssetsApiBody>,
) -> Result<Json<LegacyGetAssetsApiResponse>, ApiError> {
    use std::collections::HashMap;
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    let asset_type = body.asset_type.trim().to_lowercase();
    if asset_type != "role" && asset_type != "scene" && asset_type != "tool" {
        return Err(ApiError::BadRequest(
            "type must be role, scene, or tool".into(),
        ));
    }

    let page = body.page.unwrap_or(1);
    let limit = body.limit.unwrap_or(10);
    if page <= 0 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if limit <= 0 {
        return Err(ApiError::BadRequest("limit must be >= 1".into()));
    }
    let limit = i64::from(limit).min(MAX_ASSET_LIST_LIMIT);
    let offset = i64::from(page - 1) * limit;

    let name_pattern = body
        .name
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| format!("%{s}%"));

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::BIGINT
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.asset_type = $3
          AND (
            NOT (a.metadata ? 'assetsId')
            OR jsonb_typeof(a.metadata->'assetsId') = 'null'
          )
          AND (
            $4::text IS NULL
            OR a.name ILIKE $4
          )
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(&asset_type)
    .bind(name_pattern.as_deref())
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let parents: Vec<LegacyGetAssetsApiDbRow> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          CASE
            WHEN COALESCE(a.metadata->>'projectId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'projectId')::integer
            ELSE NULL
          END AS project_id,
          a.asset_type,
          a.name,
          CASE
            WHEN COALESCE(a.metadata->>'assetsId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'assetsId')::integer
            ELSE NULL
          END AS assets_id,
          CASE
            WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'imageId')::integer
            ELSE NULL
          END AS image_id,
          ai.file_path,
          ai.state,
          ai.metadata->>'errorReason' AS error_reason
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.legacy_image_id = CASE
           WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
             THEN (a.metadata->>'imageId')::integer
           ELSE NULL
         END
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.asset_type = $3
          AND (
            NOT (a.metadata ? 'assetsId')
            OR jsonb_typeof(a.metadata->'assetsId') = 'null'
          )
          AND (
            $4::text IS NULL
            OR a.name ILIKE $4
          )
        ORDER BY a.legacy_id ASC
        LIMIT $5 OFFSET $6
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(&asset_type)
    .bind(name_pattern.as_deref())
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let children: Vec<LegacyGetAssetsApiDbRow> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          CASE
            WHEN COALESCE(a.metadata->>'projectId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'projectId')::integer
            ELSE NULL
          END AS project_id,
          a.asset_type,
          a.name,
          CASE
            WHEN COALESCE(a.metadata->>'assetsId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'assetsId')::integer
            ELSE NULL
          END AS assets_id,
          CASE
            WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
              THEN (a.metadata->>'imageId')::integer
            ELSE NULL
          END AS image_id,
          ai.file_path,
          ai.state,
          ai.metadata->>'errorReason' AS error_reason
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.legacy_image_id = CASE
           WHEN COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
             THEN (a.metadata->>'imageId')::integer
           ELSE NULL
         END
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.asset_type = $3
          AND (
            a.metadata ? 'assetsId'
            AND jsonb_typeof(a.metadata->'assetsId') <> 'null'
          )
          AND (
            $4::text IS NULL
            OR a.name ILIKE $4
          )
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(&asset_type)
    .bind(name_pattern.as_deref())
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut child_map: HashMap<i32, Vec<LegacyGetAssetsApiChildItem>> = HashMap::new();
    for row in children {
        let child = LegacyGetAssetsApiChildItem {
            id: row.id,
            project_id: row.project_id.unwrap_or(body.project_id),
            asset_type: row.asset_type,
            name: row.name,
            assets_id: row.assets_id,
            image_id: row.image_id,
            src: row.file_path.clone(),
            file_path: row.file_path,
            state: row.state,
            error_reason: row.error_reason,
        };
        if let Some(parent_id) = child.assets_id {
            child_map.entry(parent_id).or_default().push(child);
        }
    }

    let data = parents
        .into_iter()
        .map(|row| LegacyGetAssetsApiParentItem {
            id: row.id,
            project_id: row.project_id.unwrap_or(body.project_id),
            asset_type: row.asset_type,
            name: row.name,
            assets_id: row.assets_id,
            image_id: row.image_id,
            src: row.file_path.clone(),
            file_path: row.file_path,
            state: row.state,
            error_reason: row.error_reason,
            son_assets: child_map.remove(&row.id).unwrap_or_default(),
        })
        .collect();

    Ok(Json(LegacyGetAssetsApiResponse { data, total }))
}

pub(super) async fn post_legacy_get_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyGetImageBody>,
) -> Result<Json<LegacyGetImageResponse>, ApiError> {
    use super::metadata_cover_legacy_image_id;
    let uid = require_user_uuid(&state, &headers)?;
    if body.assets_id <= 0 {
        return Err(ApiError::BadRequest("assetsId must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset = sqlx::query_as::<_, LegacyGetImageAssetRow>(
        r#"
        SELECT a.id, a.legacy_id, a.asset_type, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND a.legacy_id = $2
        ORDER BY a.created_at DESC
        LIMIT 1
        "#,
    )
    .bind(uid)
    .bind(body.assets_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let image_id = metadata_cover_legacy_image_id(&asset.metadata.0);

    let rows: Vec<AssetImageRow> = sqlx::query_as(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, legacy_image_id
        FROM app_asset_image
        WHERE asset_id = $1
        ORDER BY sort_index ASC, created_at ASC, id ASC
        "#,
    )
    .bind(asset.id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let temp_assets = rows
        .into_iter()
        .map(|row| LegacyGetImageTempAssetItem {
            id: row.legacy_image_id,
            image_uuid: row.id,
            file_path: row.file_path.unwrap_or_default(),
            assets_id: asset.legacy_id,
            asset_type: asset.asset_type.clone(),
            state: row.state,
            selected: image_id.is_some_and(|x| row.legacy_image_id == Some(x)),
        })
        .collect();

    Ok(Json(LegacyGetImageResponse {
        id: asset.legacy_id,
        image_id,
        temp_assets,
    }))
}

pub(super) async fn post_legacy_upload_clip(
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

pub(super) async fn post_legacy_get_material_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyGetMaterialDataBody>,
) -> Result<Json<LegacyGetMaterialDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut data: Vec<LegacyMaterialAssetItem> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          a.name AS name,
          COALESCE(sel.file_path, '') AS file_path,
          a.asset_type AS asset_type
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN LATERAL (
          SELECT ai.file_path
          FROM app_asset_image ai
          WHERE ai.asset_id = a.id
          ORDER BY
            CASE
              WHEN ai.legacy_image_id = (
                CASE
                  WHEN jsonb_typeof(a.metadata->'imageId') = 'number'
                    THEN (a.metadata->>'imageId')::integer
                  ELSE NULL
                END
              ) THEN 0
              ELSE 1
            END,
            ai.sort_index ASC,
            ai.created_at ASC,
            ai.id ASC
          LIMIT 1
        ) sel ON TRUE
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.asset_type = 'clip'
        ORDER BY a.create_time_ms DESC NULLS LAST, a.legacy_id DESC
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    data.push(LegacyMaterialAssetItem {
        id: 0,
        name: "Toonflow片尾".into(),
        file_path: String::new(),
        asset_type: "clip".into(),
    });

    let video: Vec<LegacyMaterialVideoItem> = sqlx::query_as(
        r#"
        SELECT
          v.legacy_id AS id,
          COALESCE(v.file_path, '') AS file_path,
          (
            SELECT vt.legacy_id
            FROM app_video_track vt
            WHERE vt.project_id = v.project_id
              AND (vt.select_video_id = v.legacy_id OR vt.video_id = v.id)
            ORDER BY vt.updated_at DESC, vt.created_at DESC, vt.id DESC
            LIMIT 1
          ) AS video_track_id
        FROM app_video v
        INNER JOIN app_project p ON p.id = v.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND v.state IN ('生成成功', '已完成', 'succeeded', 'completed')
        ORDER BY v.legacy_id DESC
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(LegacyGetMaterialDataResponse { data, video }))
}

pub(super) async fn post_legacy_batch_generation_data(
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

pub(super) async fn post_legacy_polling_image_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyPollingImageAssetsBody>,
) -> Result<Json<Vec<LegacyPollingImageAssetsItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Ok(Json(Vec::new()));
    }
    if body.ids.len() > 200 {
        return Err(ApiError::BadRequest(
            "ids must have at most 200 rows".into(),
        ));
    }
    if body.ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("each ids[] must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows: Vec<LegacyPollingImageAssetsItem> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          ai.state AS state,
          ai.file_path AS file_path
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_asset_image ai
          ON ai.asset_id = a.id
         AND ai.legacy_image_id = (
           CASE
             WHEN jsonb_typeof(a.metadata->'imageId') = 'number'
               THEN (a.metadata->>'imageId')::integer
             ELSE NULL
           END
         )
        WHERE p.owner_user_id = $1
          AND a.legacy_id = ANY($2)
          AND ai.state <> '生成中'
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

pub(super) async fn post_legacy_polling_prompt_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyPollingPromptAssetsBody>,
) -> Result<Json<Vec<LegacyPollingPromptAssetsItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Ok(Json(Vec::new()));
    }
    if body.ids.len() > 200 {
        return Err(ApiError::BadRequest(
            "ids must have at most 200 rows".into(),
        ));
    }
    if body.ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("each ids[] must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows: Vec<LegacyPollingPromptAssetsItem> = sqlx::query_as(
        r#"
        SELECT
          a.legacy_id AS id,
          a.name AS name,
          a.asset_type AS asset_type,
          COALESCE(
            CASE pj.status
              WHEN 'queued' THEN '生成中'
              WHEN 'running' THEN '生成中'
              WHEN 'succeeded' THEN '已完成'
              WHEN 'failed' THEN '失败'
              WHEN 'cancelled' THEN '已取消'
              ELSE NULL
            END,
            '已完成'
          ) AS prompt_state
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN LATERAL (
          SELECT j.status
          FROM app_generation_job j
          WHERE j.owner_user_id = $1
            AND j.kind IN ('asset.polish.prompt', 'asset.polish.batch')
            AND (
              (
                j.kind = 'asset.polish.prompt'
                AND NULLIF(j.payload->>'asset_legacy_id', '')::integer = a.legacy_id
              )
              OR (
                j.kind = 'asset.polish.batch'
                AND EXISTS (
                  SELECT 1
                  FROM jsonb_array_elements(COALESCE(j.payload->'items', '[]'::jsonb)) it
                  WHERE NULLIF(it->>'asset_legacy_id', '')::integer = a.legacy_id
                )
              )
            )
          ORDER BY j.updated_at DESC, j.created_at DESC, j.id DESC
          LIMIT 1
        ) pj ON TRUE
        WHERE p.owner_user_id = $1
          AND a.legacy_id = ANY($2)
          AND COALESCE(
            CASE pj.status
              WHEN 'queued' THEN '生成中'
              WHEN 'running' THEN '生成中'
              WHEN 'succeeded' THEN '已完成'
              WHEN 'failed' THEN '失败'
              WHEN 'cancelled' THEN '已取消'
              ELSE NULL
            END,
            '已完成'
          ) <> '生成中'
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}
