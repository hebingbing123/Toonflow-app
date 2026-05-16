//! 部分更新与删除剧本。

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

use super::super::types::{PatchScriptBody, ScriptRow};

pub(in crate::scripting::scripts) async fn patch_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchScriptBody>,
) -> Result<Json<ScriptRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Validate workspace member write access to project
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    patch_script_inner(pool, script_numeric_id, body, project_id).await
}

async fn patch_script_inner(
    pool: &PgPool,
    numeric_id: i32,
    body: PatchScriptBody,
    project_id: Uuid,
) -> Result<Json<ScriptRow>, ApiError> {
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
        SELECT id, project_id, numeric_id, name, content, extract_state, create_time_ms
        FROM app_script
        WHERE project_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(numeric_id)
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
        RETURNING id, project_id, numeric_id, name, content, extract_state, create_time_ms
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

pub(in crate::scripting::scripts) async fn delete_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Validate workspace member write access to project
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_script
        WHERE project_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(script_numeric_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}
