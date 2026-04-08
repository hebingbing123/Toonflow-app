//! Project-scoped **`app_asset`** HTTP API and **`app_script_asset`** links (legacy listing / **`o_scriptAssets`** parity).

use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Redirect, Response},
    routing::{get, post, put},
    Json, Router,
};
use base64::Engine;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, FromRow, PgPool, Postgres, QueryBuilder};
use std::collections::HashMap;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::json_patch::{parse_optional_i32_field, parse_optional_text_field, FieldPatch};
use crate::state::AppState;

const ADV_LOCK_ASSET_LEGACY: i64 = 884_422_004;
const ADV_LOCK_ASSET_IMAGE_LEGACY: i64 = 884_422_005;
const MAX_ASSET_LIST_LIMIT: i64 = 200;
const MAX_UPLOAD_CLIP_BASE64_LEN: usize = 24_000_000;

#[derive(Debug, FromRow, Serialize)]
pub struct AssetRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct ListAssetsQuery {
    /// When set, only assets linked to this script (**`app_script.legacy_id`**) within the project.
    #[serde(default)]
    pub script_legacy_id: Option<i32>,
    /// **`role`**, **`tool`**, or **`scene`** (legacy getAssetsApi **`type`**).
    #[serde(default)]
    pub asset_type: Option<String>,
    /// Case-insensitive substring match on **`name`** (SQL **`ILIKE`**).
    #[serde(default)]
    pub name: Option<String>,
    /// 1-based page when **`limit`** is set (default **1**).
    #[serde(default)]
    pub page: Option<u32>,
    /// Page size; omit for an unpaged list (all matching rows).
    #[serde(default)]
    pub limit: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ListAssetsResponse {
    pub items: Vec<AssetRow>,
    pub total: i64,
}

/// Legacy **`POST /api/cornerScape/getAllAssets`**: top-level project assets (no child **`assetsId`** in
/// promoted **`metadata`**), ordered **role → scene → tool**. **`history_images`** comes from **`app_asset_image`**
/// rows with **`state = '已完成'`** (legacy **`o_image`**), ordered by **`sort_index`**, then **`created_at`**;
/// **`metadata`** retains legacy snapshot fields on **`app_asset`** (e.g. **`imageId`**).
#[derive(Debug, Serialize)]
pub struct CornerScapeAssetItem {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
    pub metadata: Value,
    pub history_images: Vec<Value>,
}

#[derive(Debug, Serialize)]
pub struct CornerScapeResponse {
    pub items: Vec<CornerScapeAssetItem>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CornerScapeBody {
    /// When set and non-empty, restrict to these **`app_asset.asset_type`** values (**`role`**, **`scene`**, **`tool`**).
    #[serde(default)]
    types: Option<Vec<String>>,
}

#[derive(Debug, FromRow)]
struct CornerScapeDbRow {
    id: Uuid,
    legacy_id: i32,
    name: String,
    asset_type: String,
    description: Option<String>,
    create_time_ms: Option<i64>,
    metadata: SqlxJson<Value>,
    history_images: SqlxJson<Value>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CreateAssetBody {
    name: String,
    #[serde(rename = "type")]
    asset_type: String,
    #[serde(default)]
    description: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct PatchAssetBody {
    #[serde(default)]
    name: Option<Value>,
    #[serde(default)]
    description: Option<Value>,
    #[serde(default)]
    asset_type: Option<Value>,
    /// Maps to **`app_asset.metadata.imageId`** (legacy **`o_assets.imageId`**); **`null`** clears. Must match an existing **`app_asset_image.legacy_image_id`** for this asset when set to a number.
    #[serde(default)]
    cover_legacy_image_id: Option<Value>,
}

/// One **`app_asset_image`** row returned after **`GET`/`POST …/images`** or **`PATCH …/images/{image_id}`**.
#[derive(Debug, FromRow, Serialize)]
pub struct AssetImageRow {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub sort_index: i32,
    pub file_path: Option<String>,
    pub state: Option<String>,
    /// SQLite **`o_image.id`** when the row was inserted by **`promote_legacy_from_staging`**; **`NULL`** for API-created rows.
    pub legacy_image_id: Option<i32>,
}

/// **`GET …/images`** list item: same row shape as **`AssetImageRow`** plus **`selected`** (legacy **`/api/assets/getImage`** **`tempAssets[].selected`**).
#[derive(Debug, Serialize)]
pub struct AssetImageListItem {
    #[serde(flatten)]
    pub row: AssetImageRow,
    pub selected: bool,
}

#[derive(Debug, Serialize)]
pub struct ListAssetImagesResponse {
    /// Legacy **`o_assets.imageId`** read from **`app_asset.metadata.imageId`** after promote (or manual JSON); **`null`** if unset.
    pub cover_legacy_image_id: Option<i32>,
    pub items: Vec<AssetImageListItem>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CreateAssetImageBody {
    #[serde(default)]
    file_path: Option<String>,
    #[serde(default)]
    state: Option<String>,
    #[serde(default)]
    sort_index: Option<i32>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct PatchAssetImageBody {
    #[serde(default)]
    file_path: Option<Value>,
    #[serde(default)]
    state: Option<Value>,
    #[serde(default)]
    sort_index: Option<Value>,
}

#[derive(Debug, FromRow)]
struct AssetImageFileSource {
    file_path: Option<String>,
    metadata: SqlxJson<Value>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyGetImageBody {
    assets_id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyUploadClipBody {
    project_id: i32,
    base64_data: String,
    #[serde(default, alias = "type")]
    asset_type: Option<String>,
    name: String,
}

#[derive(Debug, Serialize)]
struct LegacyUploadClipResponse {
    message: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct LegacyPollingImageAssetsBody {
    ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct LegacyPollingImageAssetsItem {
    id: i32,
    state: Option<String>,
    file_path: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct LegacyPollingPromptAssetsBody {
    ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyGetMaterialDataBody {
    project_id: i32,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct LegacyMaterialAssetItem {
    id: i32,
    name: String,
    file_path: String,
    #[serde(rename = "type")]
    asset_type: String,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct LegacyMaterialVideoItem {
    id: i32,
    file_path: String,
    video_track_id: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyGetMaterialDataResponse {
    data: Vec<LegacyMaterialAssetItem>,
    video: Vec<LegacyMaterialVideoItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyBatchGenerationDataBody {
    project_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    #[serde(default)]
    name: Option<String>,
    page: i32,
    limit: i32,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct LegacyBatchGenerationAssetItem {
    id: i32,
    name: String,
    #[serde(rename = "type")]
    asset_type: String,
    description: Option<String>,
    create_time_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyBatchGenerationDataResponse {
    data: Vec<LegacyBatchGenerationAssetItem>,
    total: i64,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct LegacyPollingPromptAssetsItem {
    id: i32,
    name: String,
    #[serde(rename = "type")]
    asset_type: String,
    prompt_state: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyGetImageTempAssetItem {
    id: Option<i32>,
    image_uuid: Uuid,
    file_path: String,
    assets_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    state: Option<String>,
    selected: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyGetImageResponse {
    id: i32,
    image_id: Option<i32>,
    temp_assets: Vec<LegacyGetImageTempAssetItem>,
}

#[derive(Debug, FromRow)]
struct LegacyGetImageAssetRow {
    id: Uuid,
    legacy_id: i32,
    asset_type: String,
    metadata: SqlxJson<Value>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyGetAssetsApiBody {
    project_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    page: Option<i32>,
    #[serde(default)]
    limit: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyGetAssetsApiChildItem {
    id: i32,
    project_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    name: String,
    assets_id: Option<i32>,
    image_id: Option<i32>,
    file_path: Option<String>,
    state: Option<String>,
    error_reason: Option<String>,
    src: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyGetAssetsApiParentItem {
    id: i32,
    project_id: i32,
    #[serde(rename = "type")]
    asset_type: String,
    name: String,
    assets_id: Option<i32>,
    image_id: Option<i32>,
    file_path: Option<String>,
    state: Option<String>,
    error_reason: Option<String>,
    src: Option<String>,
    son_assets: Vec<LegacyGetAssetsApiChildItem>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyGetAssetsApiResponse {
    data: Vec<LegacyGetAssetsApiParentItem>,
    total: i64,
}

#[derive(Debug, FromRow)]
struct LegacyGetAssetsApiDbRow {
    id: i32,
    project_id: Option<i32>,
    asset_type: String,
    name: String,
    assets_id: Option<i32>,
    image_id: Option<i32>,
    file_path: Option<String>,
    state: Option<String>,
    error_reason: Option<String>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/assets/get-assets-api", post(post_legacy_get_assets_api))
        .route("/api/v1/assets/get-image", post(post_legacy_get_image))
        .route("/api/v1/assets/upload-clip", post(post_legacy_upload_clip))
        .route(
            "/api/v1/assets/get-material-data",
            post(post_legacy_get_material_data),
        )
        .route(
            "/api/v1/assets/batch-generation-data",
            post(post_legacy_batch_generation_data),
        )
        .route(
            "/api/v1/assets/polling-image-assets",
            post(post_legacy_polling_image_assets),
        )
        .route(
            "/api/v1/assets/polling-prompt-assets",
            post(post_legacy_polling_prompt_assets),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets",
            get(list_project_assets).post(create_project_asset),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/corner-scape",
            post(list_corner_scape_assets),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}/file",
            get(get_project_asset_image_file),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}",
            get(get_project_asset_image)
                .patch(patch_project_asset_image)
                .delete(delete_project_asset_image),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images",
            get(list_project_asset_images).post(create_project_asset_image),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}",
            get(get_project_asset_by_legacy)
                .patch(patch_project_asset_by_legacy)
                .delete(delete_project_asset_by_legacy),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/scripts/{script_legacy_id}/assets/{asset_legacy_id}",
            put(link_script_to_asset).delete(unlink_script_from_asset),
        )
}

async fn post_legacy_get_assets_api(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyGetAssetsApiBody>,
) -> Result<Json<LegacyGetAssetsApiResponse>, ApiError> {
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

async fn post_legacy_get_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyGetImageBody>,
) -> Result<Json<LegacyGetImageResponse>, ApiError> {
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

fn normalize_upload_clip_data_uri(raw: &str) -> Result<String, ApiError> {
    let input = raw.trim();
    if input.is_empty() {
        return Err(ApiError::BadRequest("base64Data must not be empty".into()));
    }

    let (prefix, payload) = if let Some(rest) = input.strip_prefix("data:") {
        let comma_idx = rest
            .find(',')
            .ok_or_else(|| ApiError::BadRequest("base64Data must be a valid data URI".into()))?;
        let data_uri_prefix = &input[..(5 + comma_idx)];
        if !data_uri_prefix.to_ascii_lowercase().contains(";base64") {
            return Err(ApiError::BadRequest(
                "base64Data data URI must include ;base64".into(),
            ));
        }
        (Some(data_uri_prefix), &rest[(comma_idx + 1)..])
    } else {
        (None, input)
    };

    if payload.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }
    if payload.len() > MAX_UPLOAD_CLIP_BASE64_LEN {
        return Err(ApiError::BadRequest(format!(
            "base64Data exceeds max length {}",
            MAX_UPLOAD_CLIP_BASE64_LEN
        )));
    }
    let decoded = base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| ApiError::BadRequest("base64Data must be valid base64".into()))?;
    if decoded.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }

    Ok(match prefix {
        Some(prefix) => format!("{prefix},{payload}"),
        None => format!("data:application/octet-stream;base64,{payload}"),
    })
}

async fn post_legacy_upload_clip(
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

async fn post_legacy_get_material_data(
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

async fn post_legacy_batch_generation_data(
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

async fn post_legacy_polling_image_assets(
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

async fn post_legacy_polling_prompt_assets(
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

/// Resolves **`app_script.id`** and **`app_asset.id`** when both belong to the same owned project.
async fn resolve_script_and_asset_in_project(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
    script_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<(Uuid, Uuid), ApiError> {
    let row: Option<(Uuid, Uuid)> = sqlx::query_as(
        r#"
        SELECT s.id, a.id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        INNER JOIN app_asset a ON a.project_id = p.id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND s.legacy_id = $3
          AND a.legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(script_legacy_id)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or(ApiError::NotFound)
}

async fn link_script_to_asset(
    State(state): State<AppState>,
    Path((project_legacy_id, script_legacy_id, asset_legacy_id)): Path<(i32, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || script_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let (script_id, asset_id) = resolve_script_and_asset_in_project(
        pool,
        uid,
        project_legacy_id,
        script_legacy_id,
        asset_legacy_id,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_script_asset (script_id, asset_id)
        VALUES ($1, $2)
        ON CONFLICT (script_id, asset_id) DO NOTHING
        "#,
    )
    .bind(script_id)
    .bind(asset_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}

async fn unlink_script_from_asset(
    State(state): State<AppState>,
    Path((project_legacy_id, script_legacy_id, asset_legacy_id)): Path<(i32, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || script_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let (script_id, asset_id) = resolve_script_and_asset_in_project(
        pool,
        uid,
        project_legacy_id,
        script_legacy_id,
        asset_legacy_id,
    )
    .await?;

    let res = sqlx::query(r#"DELETE FROM app_script_asset WHERE script_id = $1 AND asset_id = $2"#)
        .bind(script_id)
        .bind(asset_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn create_project_asset(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetBody>,
) -> Result<(StatusCode, Json<AssetRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    let name = body.name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let t = body.asset_type.trim().to_lowercase();
    if t != "role" && t != "tool" && t != "scene" {
        return Err(ApiError::BadRequest(
            "type must be role, tool, or scene".into(),
        ));
    }

    let desc = body
        .description
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2"#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let exists: bool = sqlx::query_scalar(
        r#"SELECT EXISTS (SELECT 1 FROM app_asset WHERE project_id = $1 AND name = $2)"#,
    )
    .bind(project_uuid)
    .bind(&name)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if exists {
        tx.rollback().await.ok();
        return Err(ApiError::Conflict(
            "an asset with this name already exists in the project".into(),
        ));
    }

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

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        INSERT INTO app_asset (
          project_id, legacy_id, name, asset_type, description, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
        RETURNING id, legacy_id, name, asset_type, description, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_legacy)
    .bind(&name)
    .bind(&t)
    .bind(desc)
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

fn normalize_list_asset_type_filter(raw: Option<String>) -> Result<Option<String>, ApiError> {
    let Some(s) = raw else {
        return Ok(None);
    };
    let t = s.trim().to_lowercase();
    if t.is_empty() {
        return Ok(None);
    }
    if t != "role" && t != "tool" && t != "scene" {
        return Err(ApiError::BadRequest(
            "asset_type must be role, tool, or scene".into(),
        ));
    }
    Ok(Some(t))
}

fn normalize_name_ilike(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(format!("%{t}%"))
        }
    })
}

/// Returns **`None`** when the filter is absent or empty (no type restriction).
fn normalize_corner_types_filter(
    raw: Option<Vec<String>>,
) -> Result<Option<Vec<String>>, ApiError> {
    let Some(list) = raw else {
        return Ok(None);
    };
    if list.is_empty() {
        return Ok(None);
    }
    let mut out = Vec::new();
    for s in list {
        let t = s.trim().to_lowercase();
        if t != "role" && t != "scene" && t != "tool" {
            return Err(ApiError::BadRequest(format!(
                "types entries must be role, scene, or tool (got {s:?})"
            )));
        }
        out.push(t);
    }
    Ok(Some(out))
}

async fn list_corner_scape_assets(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<CornerScapeBody>,
) -> Result<Json<CornerScapeResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    let type_filter = normalize_corner_types_filter(body.types)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT
          a.id,
          a.legacy_id,
          a.name,
          a.asset_type,
          a.description,
          a.create_time_ms,
          a.metadata,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id', i.id,
                  'file_path', i.file_path,
                  'state', i.state,
                  'sort_index', i.sort_index,
                  'legacy_image_id', i.legacy_image_id
                )
                ORDER BY i.sort_index ASC, i.created_at ASC
              )
              FROM app_asset_image i
              WHERE i.asset_id = a.id
                AND i.state = '已完成'
            ),
            '[]'::jsonb
          ) AS history_images
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    qb.push(
        r#"
          AND (
            NOT (a.metadata ? 'assetsId')
            OR jsonb_typeof(a.metadata->'assetsId') = 'null'
          )
        "#,
    );
    if let Some(types) = type_filter.as_ref() {
        qb.push(" AND a.asset_type IN (");
        let mut sep = qb.separated(", ");
        for t in types {
            sep.push_bind(t);
        }
        qb.push(")");
    }
    qb.push(
        r#"
        ORDER BY CASE a.asset_type
          WHEN 'role' THEN 1
          WHEN 'scene' THEN 2
          WHEN 'tool' THEN 3
          ELSE 4
        END,
        a.legacy_id ASC
        "#,
    );

    let rows: Vec<CornerScapeDbRow> = qb
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = rows
        .into_iter()
        .map(|r| CornerScapeAssetItem {
            id: r.id,
            legacy_id: r.legacy_id,
            name: r.name,
            asset_type: r.asset_type,
            description: r.description,
            create_time_ms: r.create_time_ms,
            metadata: r.metadata.0,
            history_images: match r.history_images.0 {
                Value::Array(a) => a,
                _ => Vec::new(),
            },
        })
        .collect();

    Ok(Json(CornerScapeResponse { items }))
}

async fn count_project_assets_filtered(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    script_legacy_id: Option<i32>,
    asset_type: Option<&str>,
    name_ilike: Option<&str>,
) -> Result<i64, ApiError> {
    let mut qb: QueryBuilder<Postgres> = if let Some(sid) = script_legacy_id {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT COUNT(DISTINCT a.id)::BIGINT
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id
            INNER JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb.push(" AND s.legacy_id = ");
        qb.push_bind(sid);
        qb
    } else {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT COUNT(a.id)::BIGINT
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb
    };
    if let Some(t) = asset_type {
        qb.push(" AND a.asset_type = ");
        qb.push_bind(t);
    }
    if let Some(pat) = name_ilike {
        qb.push(" AND a.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn select_project_assets_filtered(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    script_legacy_id: Option<i32>,
    asset_type: Option<&str>,
    name_ilike: Option<&str>,
    limit_offset: Option<(i64, i64)>,
) -> Result<Vec<AssetRow>, ApiError> {
    let mut qb: QueryBuilder<Postgres> = if let Some(sid) = script_legacy_id {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT DISTINCT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id
            INNER JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb.push(" AND s.legacy_id = ");
        qb.push_bind(sid);
        qb
    } else {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.legacy_id = "#,
        );
        qb.push_bind(project_legacy_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb
    };
    if let Some(t) = asset_type {
        qb.push(" AND a.asset_type = ");
        qb.push_bind(t);
    }
    if let Some(pat) = name_ilike {
        qb.push(" AND a.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(" ORDER BY a.legacy_id ASC ");
    if let Some((lim, off)) = limit_offset {
        qb.push(" LIMIT ");
        qb.push_bind(lim);
        qb.push(" OFFSET ");
        qb.push_bind(off);
    }
    qb.build_query_as::<AssetRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn list_project_assets(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    Query(query): Query<ListAssetsQuery>,
    headers: HeaderMap,
) -> Result<Json<ListAssetsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }

    if let Some(sid) = query.script_legacy_id {
        if sid <= 0 {
            return Err(ApiError::BadRequest(
                "script_legacy_id must be positive when set".into(),
            ));
        }
        let script_ok: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS (
              SELECT 1
              FROM app_script s
              INNER JOIN app_project p ON p.id = s.project_id
              WHERE p.legacy_id = $1
                AND p.owner_user_id = $2
                AND s.legacy_id = $3
            )
            "#,
        )
        .bind(project_legacy_id)
        .bind(uid)
        .bind(sid)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if !script_ok {
            return Err(ApiError::NotFound);
        }
    }

    let type_filter = normalize_list_asset_type_filter(query.asset_type)?;
    let name_pat = normalize_name_ilike(query.name);
    let type_ref = type_filter.as_deref();
    let name_ref = name_pat.as_deref();

    let limit_clamped = match query.limit {
        None => None,
        Some(0) => {
            return Err(ApiError::BadRequest(
                "limit must be positive or omitted".into(),
            ));
        }
        Some(l) => Some(i64::from(l).min(MAX_ASSET_LIST_LIMIT)),
    };

    if query.page.is_some() && limit_clamped.is_none() {
        let p = query.page.unwrap_or(1);
        if p != 1 {
            return Err(ApiError::BadRequest(
                "page is only valid together with limit".into(),
            ));
        }
    }

    let page = query.page.unwrap_or(1);
    if page == 0 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }

    let limit_offset = limit_clamped.map(|lim| {
        let off = i64::from(page.saturating_sub(1)) * lim;
        (lim, off)
    });

    let (items, total) = if limit_offset.is_some() {
        let total = count_project_assets_filtered(
            pool,
            project_legacy_id,
            uid,
            query.script_legacy_id,
            type_ref,
            name_ref,
        )
        .await?;
        let items = select_project_assets_filtered(
            pool,
            project_legacy_id,
            uid,
            query.script_legacy_id,
            type_ref,
            name_ref,
            limit_offset,
        )
        .await?;
        (items, total)
    } else {
        let items = select_project_assets_filtered(
            pool,
            project_legacy_id,
            uid,
            query.script_legacy_id,
            type_ref,
            name_ref,
            None,
        )
        .await?;
        let total = items.len() as i64;
        (items, total)
    };

    Ok(Json(ListAssetsResponse { items, total }))
}

async fn get_project_asset_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn resolve_owned_asset_id(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<Uuid, ApiError> {
    let id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

/// Background worker: resolve **`app_asset.id`** by legacy ids and project owner (**`auth.users`** id).
pub(crate) async fn resolve_asset_id_for_job(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(owner_user_id)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
}

/// Next **`sort_index`** for a new **`app_asset_image`** row (append to history).
pub(crate) async fn next_asset_image_sort_index(
    pool: &PgPool,
    asset_id: Uuid,
) -> Result<i32, sqlx::Error> {
    let max: Option<i32> = sqlx::query_scalar(
        r#"
        SELECT MAX(sort_index) FROM app_asset_image WHERE asset_id = $1
        "#,
    )
    .bind(asset_id)
    .fetch_one(pool)
    .await?;
    Ok(max.map_or(0, |m| m.saturating_add(1)))
}

fn metadata_cover_legacy_image_id(metadata: &Value) -> Option<i32> {
    let v = metadata.get("imageId")?;
    if v.is_null() {
        return None;
    }
    if let Some(n) = v.as_i64() {
        return i32::try_from(n).ok();
    }
    if let Some(n) = v.as_u64() {
        return i32::try_from(n).ok();
    }
    v.as_str().and_then(|s| s.trim().parse::<i32>().ok())
}

async fn resolve_owned_asset_id_and_metadata(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<(Uuid, Value), ApiError> {
    let row: Option<(Uuid, SqlxJson<Value>)> = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let (id, meta) = row.ok_or(ApiError::NotFound)?;
    Ok((id, meta.0))
}

async fn list_project_asset_images(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<Json<ListAssetImagesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let (asset_id, metadata) =
        resolve_owned_asset_id_and_metadata(pool, uid, project_legacy_id, asset_legacy_id).await?;
    let cover_legacy_image_id = metadata_cover_legacy_image_id(&metadata);

    let rows = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, legacy_image_id
        FROM app_asset_image
        WHERE asset_id = $1
        ORDER BY sort_index ASC, created_at ASC
        "#,
    )
    .bind(asset_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items: Vec<AssetImageListItem> = rows
        .into_iter()
        .map(|row| {
            let selected = cover_legacy_image_id.is_some_and(|c| row.legacy_image_id == Some(c));
            AssetImageListItem { row, selected }
        })
        .collect();

    Ok(Json(ListAssetImagesResponse {
        cover_legacy_image_id,
        items,
    }))
}

async fn get_project_asset_image(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id, image_id)): Path<(i32, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<AssetImageRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id = resolve_owned_asset_id(pool, uid, project_legacy_id, asset_legacy_id).await?;

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, legacy_image_id
        FROM app_asset_image
        WHERE id = $1 AND asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

/// **`GET …/images/{id}/file`**: redirect to **`https?`** **`file_path`**, or stream a locally persisted PNG.
async fn get_project_asset_image_file(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id, image_id)): Path<(i32, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id = resolve_owned_asset_id(pool, uid, project_legacy_id, asset_legacy_id).await?;

    let row = sqlx::query_as::<_, AssetImageFileSource>(
        r#"
        SELECT i.file_path, i.metadata
        FROM app_asset_image i
        WHERE i.id = $1 AND i.asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if let Some(u) = row.file_path.as_deref() {
        if u.starts_with("http://") || u.starts_with("https://") {
            let _: axum::http::Uri = u.parse().map_err(|_| {
                ApiError::BadRequest("asset image file_path is not a valid URL".into())
            })?;
            return Ok(Redirect::temporary(u).into_response());
        }
    }

    if row.metadata.0.get("storage").and_then(|x| x.as_str()) != Some("local") {
        return Err(ApiError::NotFound);
    }

    let Some(ref root) = state.local_asset_image_dir else {
        return Err(ApiError::DatabaseError(
            "TOONFLOW_LOCAL_ASSET_IMAGE_DIR is not set; cannot serve locally stored asset images"
                .into(),
        ));
    };

    let path = root.join(uid.to_string()).join(format!("{image_id}.png"));
    let bytes = tokio::fs::read(&path)
        .await
        .map_err(|_| ApiError::NotFound)?;

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "image/png"),
            (header::CACHE_CONTROL, "private, max-age=300"),
        ],
        Body::from(bytes),
    )
        .into_response())
}

async fn create_project_asset_image(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetImageBody>,
) -> Result<(StatusCode, Json<AssetImageRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id = resolve_owned_asset_id(pool, uid, project_legacy_id, asset_legacy_id).await?;

    let file_path = body
        .file_path
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string());

    let sort_index = body.sort_index.unwrap_or(0);

    let state_val: Option<String> = match &body.state {
        None => Some("已完成".into()),
        Some(s) if s.trim().is_empty() => None,
        Some(s) => Some(s.trim().to_string()),
    };

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state)
        VALUES ($1, $2, $3, $4)
        RETURNING id, asset_id, sort_index, file_path, state, legacy_image_id
        "#,
    )
    .bind(asset_id)
    .bind(sort_index)
    .bind(file_path)
    .bind(state_val)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::DatabaseError("insert app_asset_image failed".into()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

async fn patch_project_asset_image(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id, image_id)): Path<(i32, i32, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<PatchAssetImageBody>,
) -> Result<Json<AssetImageRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id = resolve_owned_asset_id(pool, uid, project_legacy_id, asset_legacy_id).await?;

    let fp_patch = parse_optional_text_field(body.file_path, "file_path")?;
    let st_patch = parse_optional_text_field(body.state, "state")?;
    let si_patch = parse_optional_i32_field(body.sort_index, "sort_index")?;

    if matches!(fp_patch, FieldPatch::Absent)
        && matches!(st_patch, FieldPatch::Absent)
        && matches!(si_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: file_path, state, sort_index".into(),
        ));
    }

    let current = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, legacy_image_id
        FROM app_asset_image
        WHERE id = $1 AND asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_file = match &fp_patch {
        FieldPatch::Absent => current.file_path.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_state = match &st_patch {
        FieldPatch::Absent => current.state.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_sort = match &si_patch {
        FieldPatch::Absent => current.sort_index,
        FieldPatch::Set(Some(v)) => *v,
        FieldPatch::Set(None) => {
            return Err(ApiError::BadRequest(
                "sort_index cannot be null; omit to leave unchanged".into(),
            ));
        }
    };

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        UPDATE app_asset_image
        SET file_path = $1,
            state = $2,
            sort_index = $3,
            updated_at = NOW()
        WHERE id = $4 AND asset_id = $5
        RETURNING id, asset_id, sort_index, file_path, state, legacy_image_id
        "#,
    )
    .bind(new_file)
    .bind(new_state)
    .bind(new_sort)
    .bind(image_id)
    .bind(asset_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn delete_project_asset_image(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id, image_id)): Path<(i32, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id = resolve_owned_asset_id(pool, uid, project_legacy_id, asset_legacy_id).await?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_asset_image
        WHERE id = $1 AND asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

fn merge_metadata_image_id(mut meta: Value, patch: &FieldPatch<i32>) -> Value {
    if !meta.is_object() {
        meta = Value::Object(Default::default());
    }
    if let Some(obj) = meta.as_object_mut() {
        match patch {
            FieldPatch::Absent => {}
            FieldPatch::Set(None) => {
                obj.remove("imageId");
            }
            FieldPatch::Set(Some(n)) => {
                obj.insert("imageId".into(), serde_json::json!(n));
            }
        }
    }
    meta
}

async fn cover_legacy_image_exists_for_asset(
    pool: &PgPool,
    asset_id: Uuid,
    legacy_image_id: i32,
) -> Result<bool, ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS (
          SELECT 1 FROM app_asset_image
          WHERE asset_id = $1 AND legacy_image_id = $2
        )
        "#,
    )
    .bind(asset_id)
    .bind(legacy_image_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(ok)
}

fn parse_asset_type_patch(v: Option<Value>) -> Result<FieldPatch<String>, ApiError> {
    let p = parse_optional_text_field(v, "asset_type")?;
    match &p {
        FieldPatch::Absent => Ok(FieldPatch::Absent),
        FieldPatch::Set(None) => Err(ApiError::BadRequest(
            "asset_type cannot be null; omit or set role|tool|scene".into(),
        )),
        FieldPatch::Set(Some(s)) => {
            let t = s.trim().to_lowercase();
            if t != "role" && t != "tool" && t != "scene" {
                return Err(ApiError::BadRequest(
                    "asset_type must be role, tool, or scene".into(),
                ));
            }
            Ok(FieldPatch::Set(Some(t)))
        }
    }
}

#[derive(Debug, FromRow)]
struct AssetPatchCurrent {
    id: Uuid,
    name: String,
    asset_type: String,
    description: Option<String>,
    metadata: SqlxJson<Value>,
}

async fn patch_project_asset_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchAssetBody>,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let desc_patch = parse_optional_text_field(body.description, "description")?;
    let type_patch = parse_asset_type_patch(body.asset_type)?;
    let cover_patch =
        parse_optional_i32_field(body.cover_legacy_image_id, "cover_legacy_image_id")?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(desc_patch, FieldPatch::Absent)
        && matches!(type_patch, FieldPatch::Absent)
        && matches!(cover_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, description, asset_type, cover_legacy_image_id".into(),
        ));
    }

    let current = sqlx::query_as::<_, AssetPatchCurrent>(
        r#"
        SELECT a.id, a.name, a.asset_type, a.description, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if let FieldPatch::Set(Some(leg)) = &cover_patch {
        if !cover_legacy_image_exists_for_asset(pool, current.id, *leg).await? {
            return Err(ApiError::BadRequest(
                "cover_legacy_image_id must match an app_asset_image row for this asset".into(),
            ));
        }
    }

    let new_metadata = merge_metadata_image_id(current.metadata.0.clone(), &cover_patch);

    let new_name = match &name_patch {
        FieldPatch::Absent => current.name.clone(),
        FieldPatch::Set(v) => v.clone().unwrap_or_default(),
    };
    if new_name.trim().is_empty() {
        return Err(ApiError::BadRequest("name cannot be empty".into()));
    }

    let new_desc = match &desc_patch {
        FieldPatch::Absent => current.description.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_type = match &type_patch {
        FieldPatch::Absent => current.asset_type.clone(),
        FieldPatch::Set(Some(t)) => t.clone(),
        FieldPatch::Set(None) => {
            return Err(ApiError::BadRequest(
                "asset_type cannot be null; omit or set role|tool|scene".into(),
            ));
        }
    };

    if matches!(&name_patch, FieldPatch::Set(_)) && new_name != current.name {
        let clash: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS (
              SELECT 1
              FROM app_asset a
              INNER JOIN app_project p ON p.id = a.project_id
              WHERE p.legacy_id = $1
                AND p.owner_user_id = $2
                AND a.name = $3
                AND a.legacy_id <> $4
            )
            "#,
        )
        .bind(project_legacy_id)
        .bind(uid)
        .bind(&new_name)
        .bind(asset_legacy_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if clash {
            return Err(ApiError::Conflict(
                "another asset in this project already uses that name".into(),
            ));
        }
    }

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        UPDATE app_asset a
        SET name = $1,
            description = $2,
            asset_type = $3,
            metadata = $4,
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.legacy_id = $5
          AND p.owner_user_id = $6
          AND a.legacy_id = $7
        RETURNING a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
        "#,
    )
    .bind(&new_name)
    .bind(&new_desc)
    .bind(&new_type)
    .bind(SqlxJson(new_metadata))
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn delete_project_asset_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let res = sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_asset_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<PatchAssetBody>(r#"{"name":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn patch_asset_body_accepts_cover_legacy_image_id_only() {
        let b: PatchAssetBody = serde_json::from_str(r#"{"cover_legacy_image_id":42}"#).unwrap();
        assert!(b.name.is_none());
        assert_eq!(
            crate::json_patch::parse_optional_i32_field(b.cover_legacy_image_id, "c").unwrap(),
            FieldPatch::Set(Some(42))
        );
    }

    #[test]
    fn create_asset_body_accepts_minimal() {
        let b: CreateAssetBody = serde_json::from_str(r#"{"name":"Hero","type":"role"}"#).unwrap();
        assert_eq!(b.name, "Hero");
        assert_eq!(b.asset_type, "role");
    }

    #[test]
    fn create_asset_image_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CreateAssetImageBody>(r#"{"x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_asset_image_body_accepts_empty_object() {
        let b: CreateAssetImageBody = serde_json::from_str("{}").unwrap();
        assert!(b.file_path.is_none());
        assert!(b.state.is_none());
        assert!(b.sort_index.is_none());
    }

    #[test]
    fn patch_asset_image_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<PatchAssetImageBody>(r#"{"state":"x","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn upload_clip_base64_normalize_accepts_raw_payload() {
        let normalized = normalize_upload_clip_data_uri("AA==").unwrap();
        assert_eq!(normalized, "data:application/octet-stream;base64,AA==");
    }

    #[test]
    fn upload_clip_base64_normalize_accepts_data_uri_payload() {
        let normalized = normalize_upload_clip_data_uri("data:image/png;base64,AA==").unwrap();
        assert_eq!(normalized, "data:image/png;base64,AA==");
    }

    #[test]
    fn upload_clip_base64_normalize_rejects_non_base64_data_uri() {
        let err = normalize_upload_clip_data_uri("data:image/png,AA==").unwrap_err();
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains(";base64")),
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn upload_clip_base64_normalize_rejects_invalid_payload() {
        let err = normalize_upload_clip_data_uri("data:image/png;base64,not-base64").unwrap_err();
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains("valid base64")),
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn upload_clip_body_accepts_legacy_type_key() {
        let body: LegacyUploadClipBody = serde_json::from_str(
            r#"{"projectId":1,"base64Data":"AA==","type":"clip","name":"demo"}"#,
        )
        .unwrap();
        assert_eq!(body.project_id, 1);
        assert_eq!(body.asset_type.as_deref(), Some("clip"));
    }

    #[test]
    fn legacy_get_assets_api_body_accepts_minimal() {
        let body: LegacyGetAssetsApiBody =
            serde_json::from_str(r#"{"projectId":1,"type":"role"}"#).unwrap();
        assert_eq!(body.project_id, 1);
        assert_eq!(body.asset_type, "role");
        assert!(body.name.is_none());
        assert!(body.page.is_none());
        assert!(body.limit.is_none());
    }

    #[test]
    fn legacy_get_assets_api_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<LegacyGetAssetsApiBody>(
            r#"{"projectId":1,"type":"role","x":1}"#,
        )
        .unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }
}
