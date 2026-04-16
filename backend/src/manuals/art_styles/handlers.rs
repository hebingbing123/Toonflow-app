use axum::{
    extract::{Path, State},
    http::HeaderMap,
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde_json::{json, Value};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{parse_optional_text_field, FieldPatch};
use crate::llm::chat_completion_assistant_text;
use crate::state::AppState;

use super::cover::{
    art_style_cover_api_path, delete_local_art_style_cover_files, parse_uploaded_cover,
    persist_local_art_style_cover, serve_cover_by_numeric_id,
};
use super::types::{
    ArtStyleRow, CreateArtStyleBody, ExtractArtStylePromptBody, ExtractArtStylePromptResponse,
    ListArtStylesResponse, PatchArtStyleBody, ADV_LOCK_ART_STYLE_NUMERIC,
    EXTRACT_STYLE_SYSTEM_PROMPT, MAX_ART_STYLE_LIST, MAX_EXTRACT_IMAGES, MAX_IMAGE_ENTRY_BYTES,
};

pub(super) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/art-styles/extract-prompt",
            post(extract_style_prompt),
        )
        .route(
            "/api/v1/art-styles",
            get(list_art_styles).post(create_art_style),
        )
        .route(
            "/api/v1/art-styles/numeric/{numeric_id}",
            get(get_art_style_by_numeric_id)
                .patch(patch_art_style_by_numeric_id)
                .delete(delete_art_style_by_numeric_id),
        )
        .route(
            "/api/v1/art-styles/numeric/{numeric_id}/cover",
            get(get_art_style_cover_by_numeric_id),
        )
}

async fn extract_style_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExtractArtStylePromptBody>,
) -> Result<Json<ExtractArtStylePromptResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    if body.images.is_empty() {
        return Err(ApiError::BadRequest("images must be non-empty".into()));
    }
    if body.images.len() > MAX_EXTRACT_IMAGES {
        return Err(ApiError::BadRequest(format!(
            "at most {MAX_EXTRACT_IMAGES} images"
        )));
    }

    let mut parts: Vec<Value> = Vec::with_capacity(body.images.len());
    for (i, raw) in body.images.iter().enumerate() {
        let s = raw.trim();
        if s.is_empty() {
            return Err(ApiError::BadRequest(format!("images[{i}] is empty")));
        }
        if s.len() > MAX_IMAGE_ENTRY_BYTES {
            return Err(ApiError::BadRequest(format!(
                "images[{i}] exceeds max length ({MAX_IMAGE_ENTRY_BYTES} bytes)"
            )));
        }
        parts.push(json!({
            "type": "image_url",
            "image_url": { "url": s }
        }));
    }

    let cfg = state.llm.as_ref().ok_or(ApiError::LlmNotConfigured)?;

    let messages = vec![
        json!({ "role": "system", "content": EXTRACT_STYLE_SYSTEM_PROMPT }),
        json!({ "role": "user", "content": parts }),
    ];

    let text = chat_completion_assistant_text(cfg, &state.http_client, messages)
        .await
        .map_err(|e| {
            tracing::warn!(error = %e, "extract_style_prompt");
            ApiError::Internal
        })?;

    Ok(Json(ExtractArtStylePromptResponse { text }))
}

async fn list_art_styles(
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

fn trim_opt(s: Option<String>) -> Option<String> {
    s.map(|v| v.trim().to_owned()).filter(|s| !s.is_empty())
}

async fn create_art_style(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateArtStyleBody>,
) -> Result<(StatusCode, Json<ArtStyleRow>), ApiError> {
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

    Ok((StatusCode::CREATED, Json(row)))
}

async fn get_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

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

async fn patch_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<PatchArtStyleBody>,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let file_url_patch = parse_optional_text_field(body.file_url, "file_url")?;
    let label_patch = parse_optional_text_field(body.label, "label")?;
    let prompt_patch = parse_optional_text_field(body.prompt, "prompt")?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(file_url_patch, FieldPatch::Absent)
        && matches!(label_patch, FieldPatch::Absent)
        && matches!(prompt_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, file_url, label, prompt".into(),
        ));
    }

    let current = sqlx::query_as::<_, ArtStyleRow>(
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

    let new_name = match &name_patch {
        FieldPatch::Absent => current.name.clone(),
        FieldPatch::Set(v) => v.clone().unwrap_or_default(),
    };
    if new_name.trim().is_empty() {
        return Err(ApiError::BadRequest("name cannot be empty".into()));
    }

    let new_file_url = match &file_url_patch {
        FieldPatch::Absent => current.file_url.clone(),
        FieldPatch::Set(v) => v.clone(),
    };
    let new_label = match &label_patch {
        FieldPatch::Absent => current.label.clone(),
        FieldPatch::Set(v) => v.clone(),
    };
    let new_prompt = match &prompt_patch {
        FieldPatch::Absent => current.prompt.clone(),
        FieldPatch::Set(v) => v.clone(),
    };
    let uploaded_cover = match &new_file_url {
        Some(file_url) => parse_uploaded_cover(file_url)?,
        None => None,
    };
    if uploaded_cover.is_some() && state.local_art_style_cover_dir.is_none() {
        return Err(ApiError::NotImplemented(
            "TOONFLOW_LOCAL_ART_STYLE_COVER_DIR is not set; cannot persist art style base64 covers"
                .into(),
        ));
    }
    let stored_file_url = if uploaded_cover.is_some() {
        Some(art_style_cover_api_path(numeric_id))
    } else {
        new_file_url.clone()
    };

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        UPDATE app_art_style
        SET name = $1,
            file_url = $2,
            label = $3,
            prompt = $4,
            updated_at = NOW()
        WHERE owner_user_id = $5 AND numeric_id = $6
        RETURNING id, numeric_id, name, file_url, label, prompt
        "#,
    )
    .bind(&new_name)
    .bind(&stored_file_url)
    .bind(&new_label)
    .bind(&new_prompt)
    .bind(uid)
    .bind(numeric_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(root) = state.local_art_style_cover_dir.as_deref() {
        if let Some(cover) = uploaded_cover.as_ref() {
            persist_local_art_style_cover(root, uid, numeric_id, cover).await?;
        } else if matches!(file_url_patch, FieldPatch::Set(_))
            && current.file_url.as_deref() == Some(art_style_cover_api_path(numeric_id).as_str())
            && stored_file_url.as_deref() != Some(art_style_cover_api_path(numeric_id).as_str())
        {
            delete_local_art_style_cover_files(root, uid, numeric_id).await;
        }
    }

    Ok(Json(row))
}

async fn delete_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

    let res =
        sqlx::query(r#"DELETE FROM app_art_style WHERE owner_user_id = $1 AND numeric_id = $2"#)
            .bind(uid)
            .bind(numeric_id)
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    if let Some(root) = state.local_art_style_cover_dir.as_deref() {
        delete_local_art_style_cover_files(root, uid, numeric_id).await;
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn get_art_style_cover_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<axum::response::Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

    serve_cover_by_numeric_id(&state, uid, numeric_id).await
}
