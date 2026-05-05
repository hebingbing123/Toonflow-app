//! `GET …/assets/{id}` — single asset row.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::models::*;
use super::resolve::ensure_owned_project_pk;

pub(crate) async fn get_project_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        SELECT a.id, a.numeric_id, a.name, a.asset_type, a.description, a.create_time_ms, a.candidate_status
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND p.owner_user_id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}
