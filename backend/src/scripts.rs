use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::json_patch::{parse_optional_i32_field, parse_optional_text_field, FieldPatch};
use crate::state::AppState;

#[derive(Debug, FromRow, Serialize)]
pub struct ScriptRow {
    pub id: Uuid,
    pub project_id: Uuid,
    pub legacy_id: i32,
    pub name: Option<String>,
    pub content: Option<String>,
    pub extract_state: Option<i32>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct PatchScriptBody {
    #[serde(default)]
    name: Option<Value>,
    #[serde(default)]
    content: Option<Value>,
    #[serde(default)]
    extract_state: Option<Value>,
}

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/scripts/legacy/{legacy_id}",
        get(get_script_by_legacy).patch(patch_script_by_legacy),
    )
}

async fn get_script_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<ScriptRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let row = sqlx::query_as::<_, ScriptRow>(
        r#"
        SELECT s.id, s.project_id, s.legacy_id, s.name, s.content, s.extract_state, s.create_time_ms
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE s.legacy_id = $1 AND p.owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn patch_script_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<PatchScriptBody>,
) -> Result<Json<ScriptRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let content_patch = parse_optional_text_field(body.content, "content")?;
    let state_patch = parse_optional_i32_field(body.extract_state, "extract_state")?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(content_patch, FieldPatch::Absent)
        && matches!(state_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, content, extract_state".into(),
        ));
    }

    let current = sqlx::query_as::<_, ScriptRow>(
        r#"
        SELECT s.id, s.project_id, s.legacy_id, s.name, s.content, s.extract_state, s.create_time_ms
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE s.legacy_id = $1 AND p.owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_name = match name_patch {
        FieldPatch::Absent => current.name.clone(),
        FieldPatch::Set(v) => v,
    };
    let new_content = match content_patch {
        FieldPatch::Absent => current.content.clone(),
        FieldPatch::Set(v) => v,
    };
    let new_state = match state_patch {
        FieldPatch::Absent => current.extract_state,
        FieldPatch::Set(v) => v,
    };

    let row = sqlx::query_as::<_, ScriptRow>(
        r#"
        UPDATE app_script
        SET name = $1, content = $2, extract_state = $3, updated_at = NOW()
        WHERE id = $4 AND project_id = $5
        RETURNING id, project_id, legacy_id, name, content, extract_state, create_time_ms
        "#,
    )
    .bind(&new_name)
    .bind(&new_content)
    .bind(new_state)
    .bind(current.id)
    .bind(current.project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_script_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<PatchScriptBody>(r#"{"name":"a","extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }
}
