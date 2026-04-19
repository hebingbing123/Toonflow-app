use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::{ArtStyleRow, ListArtStylesResponse, MAX_ART_STYLE_LIST};

pub(crate) async fn list_art_styles(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ListArtStylesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let total: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM app_art_style WHERE owner_user_id = $1"#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        SELECT id, numeric_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1
        ORDER BY numeric_id ASC
        LIMIT $2
        "#,
    )
    .bind(uid)
    .bind(MAX_ART_STYLE_LIST)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ListArtStylesResponse { items, total }))
}
