//! 资产图片列表与单条 JSON 查询。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::{
    resolve_owned_asset_id_and_metadata_for_project, resolve_owned_asset_id_for_project,
};
use super::super::models::*;
use super::super::utils::metadata_cover_numeric_image_id;

pub(in crate::assets) async fn list_project_asset_images_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<ListAssetImagesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let (asset_id, metadata) =
        resolve_owned_asset_id_and_metadata_for_project(pool, uid, project_id, asset_numeric_id)
            .await?;
    let cover_numeric_image_id = metadata_cover_numeric_image_id(&metadata);

    let rows = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, numeric_image_id
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
            let selected = cover_numeric_image_id.is_some_and(|c| row.numeric_image_id == Some(c));
            AssetImageListItem { row, selected }
        })
        .collect();

    Ok(Json(ListAssetImagesResponse {
        cover_numeric_image_id,
        items,
    }))
}

pub(in crate::assets) async fn get_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<AssetImageRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, numeric_image_id
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
