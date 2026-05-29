//! DPI-aware block asset HTTP handlers.

use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use base64::Engine;
use serde::Deserialize;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_positive, ApiError};
use crate::state::AppState;

use super::super::crud::{
    require_asset_project_read_scope, require_asset_project_write_scope,
    resolve_owned_asset_id_for_project,
};
use super::repository::{AssetBlockRepository, AssetBlockRow};
use super::service::AssetBlockService;
use super::write::AssetBlockWriteService;

#[derive(Debug, Deserialize)]
pub(in crate::assets) struct AssetBlockFileQuery {
    pub dpi: Option<i16>,
}

#[derive(Debug, Deserialize)]
pub(in crate::assets) struct CreateAssetBlockBody {
    pub block_key: String,
    pub dpi_tier: Option<i16>,
    pub width: i32,
    pub height: i32,
    pub png_base64: Option<String>,
}

pub(in crate::assets) async fn list_project_asset_blocks_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<axum::Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(asset_numeric_id, "numeric ids")?;
    let pool = state.require_pool()?;
    require_asset_project_read_scope(&state, uid, project_id).await?;
    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;
    let rows = AssetBlockRepository::list_blocks_for_asset(pool, asset_id).await?;
    Ok(axum::Json(serde_json::json!({ "blocks": rows })))
}

pub(in crate::assets) async fn create_project_asset_block_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetBlockBody>,
) -> Result<(StatusCode, Json<AssetBlockRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(asset_numeric_id, "numeric ids")?;
    let pool = state.require_pool()?;
    require_asset_project_write_scope(&state, uid, project_id).await?;
    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;

    let dpi_tier = body.dpi_tier.unwrap_or(1);
    let png_bytes = match body.png_base64.as_deref() {
        None => None,
        Some(raw) => {
            let trimmed = raw.trim();
            if trimmed.is_empty() {
                None
            } else {
                let payload = trimmed
                    .strip_prefix("data:image/png;base64,")
                    .unwrap_or(trimmed);
                Some(
                    base64::engine::general_purpose::STANDARD
                        .decode(payload)
                        .map_err(|_| {
                            bad_request_i18n(
                                "png_base64 is not valid base64",
                                "png_base64 不是有效的 base64",
                            )
                        })?,
                )
            }
        }
    };

    let row = AssetBlockWriteService::create_block(
        pool,
        asset_id,
        &body.block_key,
        dpi_tier,
        body.width,
        body.height,
        png_bytes.as_deref(),
        state.local_asset_image_dir.as_deref(),
        uid,
    )
    .await?;

    Ok((StatusCode::CREATED, Json(row)))
}

pub(in crate::assets) async fn get_project_asset_block_file_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id, block_key)): Path<(Uuid, i32, String)>,
    Query(query): Query<AssetBlockFileQuery>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(asset_numeric_id, "numeric ids")?;
    let pool = state.require_pool()?;
    require_asset_project_read_scope(&state, uid, project_id).await?;
    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;

    let row =
        AssetBlockService::get_block_for_delivery(pool, asset_id, &block_key, query.dpi).await?;

    let Some(ref root) = state.local_asset_image_dir else {
        return Err(ApiError::DatabaseError(
            "OPENFLOW_LOCAL_ASSET_IMAGE_DIR is not set".into(),
        ));
    };

    let path = AssetBlockService::resolve_local_block_path(root, uid, row.id);
    let file = tokio::fs::File::open(&path)
        .await
        .map_err(|_| ApiError::NotFound)?;
    let stream = tokio_util::io::ReaderStream::new(file);
    let body = Body::from_stream(stream);

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "image/png"),
            (header::CACHE_CONTROL, "private, max-age=600"),
        ],
        body,
    )
        .into_response())
}
