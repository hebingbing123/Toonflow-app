//! User-scoped **`app_art_style`** REST (legacy **`o_artStyle`** list/get/create/update/delete subset).

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::json_patch::{parse_optional_text_field, FieldPatch};
use crate::state::AppState;

const ADV_LOCK_ART_STYLE_LEGACY: i64 = 884_422_008;
const MAX_ART_STYLE_LIST: i64 = 500;

#[derive(Debug, FromRow, Serialize)]
pub struct ArtStyleRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub file_url: Option<String>,
    pub label: Option<String>,
    pub prompt: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ListArtStylesResponse {
    pub items: Vec<ArtStyleRow>,
    pub total: i64,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct CreateArtStyleBody {
    pub name: String,
    #[serde(default)]
    pub file_url: Option<String>,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub prompt: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct PatchArtStyleBody {
    #[serde(default)]
    pub name: Option<Value>,
    #[serde(default)]
    pub file_url: Option<Value>,
    #[serde(default)]
    pub label: Option<Value>,
    #[serde(default)]
    pub prompt: Option<Value>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/art-styles",
            get(list_art_styles).post(create_art_style),
        )
        .route(
            "/api/v1/art-styles/legacy/{legacy_id}",
            get(get_art_style_by_legacy)
                .patch(patch_art_style_by_legacy)
                .delete(delete_art_style_by_legacy),
        )
}

fn trim_opt(s: Option<String>) -> Option<String> {
    s.map(|v| v.trim().to_owned()).filter(|s| !s.is_empty())
}

async fn list_art_styles(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ListArtStylesResponse>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let total: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM app_art_style WHERE owner_user_id = $1"#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        SELECT id, legacy_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1
        ORDER BY legacy_id ASC
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

async fn create_art_style(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateArtStyleBody>,
) -> Result<(StatusCode, Json<ArtStyleRow>), ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let name = body.name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let file_url = trim_opt(body.file_url);
    let label = trim_opt(body.label);
    let prompt = trim_opt(body.prompt);

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ART_STYLE_LEGACY)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_art_style"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        INSERT INTO app_art_style (
          owner_user_id, legacy_id, name, file_url, label, prompt
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, legacy_id, name, file_url, label, prompt
        "#,
    )
    .bind(uid)
    .bind(next_legacy)
    .bind(&name)
    .bind(&file_url)
    .bind(&label)
    .bind(&prompt)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

async fn get_art_style_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    if legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy_id must be positive".into()));
    }

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        SELECT id, legacy_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1 AND legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn patch_art_style_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<PatchArtStyleBody>,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    if legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy_id must be positive".into()));
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
        SELECT id, legacy_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1 AND legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(legacy_id)
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

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        UPDATE app_art_style
        SET name = $1,
            file_url = $2,
            label = $3,
            prompt = $4,
            updated_at = NOW()
        WHERE owner_user_id = $5 AND legacy_id = $6
        RETURNING id, legacy_id, name, file_url, label, prompt
        "#,
    )
    .bind(&new_name)
    .bind(&new_file_url)
    .bind(&new_label)
    .bind(&new_prompt)
    .bind(uid)
    .bind(legacy_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}

async fn delete_art_style_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    if legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy_id must be positive".into()));
    }

    let res =
        sqlx::query(r#"DELETE FROM app_art_style WHERE owner_user_id = $1 AND legacy_id = $2"#)
            .bind(uid)
            .bind(legacy_id)
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_art_style_body_accepts_minimal() {
        let j = serde_json::json!({ "name": "test" });
        let b: CreateArtStyleBody = serde_json::from_value(j).unwrap();
        assert_eq!(b.name, "test");
    }

    #[test]
    fn patch_art_style_body_rejects_unknown_fields() {
        let j = serde_json::json!({ "name": "x", "extra": 1 });
        assert!(serde_json::from_value::<PatchArtStyleBody>(j).is_err());
    }
}
