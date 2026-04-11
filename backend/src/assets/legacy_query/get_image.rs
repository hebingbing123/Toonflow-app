//! 遗留 `POST …/get-image` — 获取资产图片。
//!
//! 返回指定资产的图片列表，包括临时生成的图片和选中的封面图。

use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::metadata_cover_legacy_image_id;
use super::super::models::*;

pub(crate) async fn post_legacy_get_image(
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
