use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::cover::serve_cover_by_numeric_id;
use super::super::super::types::ArtStyleRow;
use super::super::common::require_positive_numeric_id;

pub(crate) async fn get_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    require_positive_numeric_id(numeric_id)?;

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        SELECT id, numeric_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1 AND numeric_id = $2
        "#,
    )
    .bind(uid)
    .bind(numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

pub(crate) async fn get_art_style_cover_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<axum::response::Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_numeric_id(numeric_id)?;

    serve_cover_by_numeric_id(&state, uid, numeric_id).await
}
