//! 资产图片包查询（**`POST …/assets/workbench/image-bundle`**）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::ensure_owned_project_legacy_id;
use super::super::metadata_cover_legacy_image_id;
use super::super::models::*;

async fn run_get_image(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_legacy_id: i32,
    assets_id: i32,
) -> Result<LegacyGetImageResponse, ApiError> {
    let asset = sqlx::query_as::<_, LegacyGetImageAssetRow>(
        r#"
        SELECT a.id, a.legacy_id, a.asset_type, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.legacy_id = $3
        ORDER BY a.created_at DESC
        LIMIT 1
        "#,
    )
    .bind(uid)
    .bind(project_legacy_id)
    .bind(assets_id)
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

    Ok(LegacyGetImageResponse {
        id: asset.legacy_id,
        image_id,
        temp_assets,
    })
}

pub(crate) async fn post_project_workbench_image_bundle(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
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
    let project_legacy_id = ensure_owned_project_legacy_id(pool, uid, project_id).await?;
    let out = run_get_image(pool, uid, project_legacy_id, body.assets_id).await?;
    Ok(Json(out))
}
