//! `GET …/assets` HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::models::*;
use super::super::resolve::require_asset_project_read_scope;
use super::inner::list_project_assets_inner;

pub(crate) async fn list_project_assets_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(query): Query<ListAssetsQuery>,
    headers: HeaderMap,
) -> Result<Json<ListAssetsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_asset_project_read_scope(&state, uid, project_id).await?;
    list_project_assets_inner(pool, uid, project_id, query).await
}
