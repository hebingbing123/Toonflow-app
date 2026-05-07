//! `POST …/assets/workbench/nested` HTTP 处理器。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::crud::ensure_owned_project_numeric_id;
use super::super::super::models::*;
use super::query::run_get_assets_api;

pub(crate) async fn post_project_workbench_nested_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchNestedAssetsBody>,
) -> Result<Json<WorkbenchGetAssetsApiResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
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
    let pool = state.require_pool()?;
    let project_numeric_id = ensure_owned_project_numeric_id(pool, uid, project_id).await?;
    let out = run_get_assets_api(pool, uid, project_numeric_id, &body).await?;
    Ok(Json(out))
}
