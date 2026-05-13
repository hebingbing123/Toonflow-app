mod inner;

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::assets::models::{AssetRow, PatchAssetBody};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::resolve::require_asset_project_write_scope;
use inner::patch_project_asset_inner;

pub(crate) async fn patch_project_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchAssetBody>,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    require_asset_project_write_scope(&state, uid, project_id).await?;
    patch_project_asset_inner(pool, uid, project_id, asset_numeric_id, body).await
}
