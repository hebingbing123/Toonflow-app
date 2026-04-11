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
    Path((project_id, asset_legacy_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

pub(crate) async fn get_project_asset_by_legacy(
    State(state): State<AppState>,
    Path((project_legacy_id, asset_legacy_id)): Path<(i32, i32)>,
    headers: HeaderMap,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        SELECT a.id, a.legacy_id, a.name, a.asset_type, a.description, a.create_time_ms
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}
