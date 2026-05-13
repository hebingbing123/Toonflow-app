use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_positive, ApiError};
use crate::state::AppState;

use super::super::super::crud::{
    require_asset_project_write_scope, resolve_owned_asset_id_for_project,
};
use super::super::super::models::*;

pub(in crate::assets) async fn create_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetImageBody>,
) -> Result<(StatusCode, Json<AssetImageRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(asset_numeric_id, "numeric ids")?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;

    let file_path = body
        .file_path
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string());

    let sort_index = body.sort_index.unwrap_or(0);

    let state_val: Option<String> = match &body.state {
        None => Some("已完成".into()),
        Some(s) if s.trim().is_empty() => None,
        Some(s) => Some(s.trim().to_string()),
    };

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state)
        VALUES ($1, $2, $3, $4)
        RETURNING id, asset_id, sort_index, file_path, state, numeric_image_id
        "#,
    )
    .bind(asset_id)
    .bind(sort_index)
    .bind(file_path)
    .bind(state_val)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::DatabaseError("insert app_asset_image failed".into()))?;

    Ok((StatusCode::CREATED, Json(row)))
}
