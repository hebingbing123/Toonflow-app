use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::http_kit::json_patch::{parse_optional_text_field, FieldPatch};
use crate::state::AppState;

use super::super::cover::{
    art_style_cover_api_path, delete_local_art_style_cover_files, parse_uploaded_cover,
    persist_local_art_style_cover,
};
use super::super::types::{ArtStyleRow, PatchArtStyleBody};
use super::common::require_positive_numeric_id;

pub(super) async fn patch_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<PatchArtStyleBody>,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    require_positive_numeric_id(numeric_id)?;

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let file_url_patch = parse_optional_text_field(body.file_url, "file_url")?;
    let label_patch = parse_optional_text_field(body.label, "label")?;
    let prompt_patch = parse_optional_text_field(body.prompt, "prompt")?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(file_url_patch, FieldPatch::Absent)
        && matches!(label_patch, FieldPatch::Absent)
        && matches!(prompt_patch, FieldPatch::Absent)
    {
        return Err(bad_request_i18n(
            "expected at least one of: name, file_url, label, prompt",
            "name、file_url、label、prompt 至少需要提供一个",
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
        return Err(bad_request_i18n("name cannot be empty", "name 不能为空"));
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

pub(super) async fn delete_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    require_positive_numeric_id(numeric_id)?;

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
