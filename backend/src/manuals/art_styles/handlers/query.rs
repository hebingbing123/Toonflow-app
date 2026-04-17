use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::cover::{
    art_style_cover_api_path, parse_uploaded_cover, persist_local_art_style_cover,
    serve_cover_by_numeric_id,
};
use super::super::types::{
    ArtStyleRow, CreateArtStyleBody, ListArtStylesResponse, ADV_LOCK_ART_STYLE_NUMERIC,
    MAX_ART_STYLE_LIST,
};
use super::common::{require_positive_numeric_id, trim_opt};

pub(super) async fn list_art_styles(
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

pub(super) async fn create_art_style(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateArtStyleBody>,
) -> Result<(axum::http::StatusCode, Json<ArtStyleRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let name = body.name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let file_url = trim_opt(body.file_url);
    let label = trim_opt(body.label);
    let prompt = trim_opt(body.prompt);
    let uploaded_cover = match file_url.as_deref() {
        Some(file_url) => parse_uploaded_cover(file_url)?,
        None => None,
    };
    if uploaded_cover.is_some() && state.local_art_style_cover_dir.is_none() {
        return Err(ApiError::NotImplemented(
            "TOONFLOW_LOCAL_ART_STYLE_COVER_DIR is not set; cannot persist art style base64 covers"
                .into(),
        ));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ART_STYLE_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_art_style"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        INSERT INTO app_art_style (
          owner_user_id, numeric_id, name, file_url, label, prompt
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, numeric_id, name, file_url, label, prompt
        "#,
    )
    .bind(uid)
    .bind(next_numeric_id)
    .bind(&name)
    .bind(if uploaded_cover.is_some() {
        Some(art_style_cover_api_path(next_numeric_id))
    } else {
        file_url.clone()
    })
    .bind(&label)
    .bind(&prompt)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let (Some(root), Some(cover)) = (
        state.local_art_style_cover_dir.as_deref(),
        uploaded_cover.as_ref(),
    ) {
        persist_local_art_style_cover(root, uid, next_numeric_id, cover).await?;
    }

    Ok((axum::http::StatusCode::CREATED, Json(row)))
}

pub(super) async fn get_art_style_by_numeric_id(
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

pub(super) async fn get_art_style_cover_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<axum::response::Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_numeric_id(numeric_id)?;

    serve_cover_by_numeric_id(&state, uid, numeric_id).await
}
