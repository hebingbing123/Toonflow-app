//! `GET …/assets/{id}` — single asset row.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_positive, ApiError};
use crate::state::AppState;

use super::super::models::*;
use super::resolve::require_asset_project_read_scope;

pub(crate) async fn get_project_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    validate_positive(asset_numeric_id, "numeric ids")?;

    require_asset_project_read_scope(&state, uid, project_id).await?;

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        SELECT a.id, a.numeric_id, a.name, a.asset_type, a.description, a.create_time_ms, a.candidate_status
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}
