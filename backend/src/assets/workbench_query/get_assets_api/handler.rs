//! `POST …/assets/workbench/nested` HTTP 处理器。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::state::AppState;

use super::super::super::crud::require_asset_project_read_scope;
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
        return Err(bad_request_i18n(
            "type must be role, scene, or tool",
            "type 必须是 role、scene 或 tool",
        ));
    }
    let page = body.page.unwrap_or(1);
    let limit = body.limit.unwrap_or(10);
    if page <= 0 {
        return Err(bad_request_i18n("page must be >= 1", "page 必须大于等于 1"));
    }
    if limit <= 0 {
        return Err(bad_request_i18n(
            "limit must be >= 1",
            "limit 必须大于等于 1",
        ));
    }
    let pool = state.require_pool()?;
    require_asset_project_read_scope(&state, uid, project_id).await?;
    let project_numeric_id: i32 =
        sqlx::query_scalar("SELECT numeric_id FROM app_project WHERE id = $1")
            .bind(project_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let out = run_get_assets_api(pool, project_numeric_id, &body).await?;
    Ok(Json(out))
}
