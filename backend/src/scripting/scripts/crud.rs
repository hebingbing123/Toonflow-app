//! Project-scoped script CRUD and batch-add.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    http::StatusCode,
    Json,
};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::scope;
use crate::state::AppState;

use super::types::{
    BatchAddScriptDataBody, BatchAddScriptItem, BatchAddScriptResponse, CreateScriptBody,
    PatchScriptBody, ScriptRow, ADV_LOCK_SCRIPT_NUMERIC_ID,
};

fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

async fn create_script_locked(
    tx: &mut Transaction<'_, Postgres>,
    project_uuid: Uuid,
    body: CreateScriptBody,
) -> Result<ScriptRow, ApiError> {
    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_SCRIPT_NUMERIC_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_script
        "#,
    )
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    sqlx::query_as::<_, ScriptRow>(
        r#"
        INSERT INTO app_script (
          project_id, numeric_id, name, content, extract_state, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
        RETURNING id, project_id, numeric_id, name, content, extract_state, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_numeric_id)
    .bind(trim_opt(body.name))
    .bind(trim_opt(body.content))
    .bind(body.extract_state)
    .bind(now_ms)
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn create_script_under_project_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreateScriptBody>,
) -> Result<(StatusCode, Json<ScriptRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = create_script_locked(&mut tx, project_id, body).await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

async fn batch_add_scripts_locked(
    tx: &mut Transaction<'_, Postgres>,
    project_uuid: Uuid,
    data: Vec<BatchAddScriptItem>,
) -> Result<BatchAddScriptResponse, ApiError> {
    if data.is_empty() {
        return Ok(BatchAddScriptResponse {
            message: "添加剧本成功".into(),
            inserted: 0,
            scripts: Vec::new(),
        });
    }

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_SCRIPT_NUMERIC_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_script
        "#,
    )
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let mut inserted = Vec::with_capacity(data.len());
    for item in data {
        let row = sqlx::query_as::<_, ScriptRow>(
            r#"
            INSERT INTO app_script (
              project_id, numeric_id, name, content, extract_state, create_time_ms, metadata
            )
            VALUES ($1, $2, $3, $4, NULL, $5, '{}'::jsonb)
            RETURNING id, project_id, numeric_id, name, content, extract_state, create_time_ms
            "#,
        )
        .bind(project_uuid)
        .bind(next_numeric_id)
        .bind(item.script_name)
        .bind(item.script_data)
        .bind(now_ms)
        .fetch_one(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        inserted.push(row);
        next_numeric_id += 1;
    }

    Ok(BatchAddScriptResponse {
        message: "添加剧本成功".into(),
        inserted: i32::try_from(inserted.len()).unwrap_or(i32::MAX),
        scripts: inserted,
    })
}

pub(super) async fn post_scripts_batch_add_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<BatchAddScriptDataBody>,
) -> Result<Json<BatchAddScriptResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let response = batch_add_scripts_locked(&mut tx, project_id, body.data).await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(response))
}

pub(super) async fn get_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<ScriptRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let oip = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let row = sqlx::query_as::<_, ScriptRow>(
        r#"
        SELECT id, project_id, numeric_id, name, content, extract_state, create_time_ms
        FROM app_script
        WHERE id = $1
        "#,
    )
    .bind(oip.script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

pub(super) async fn patch_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchScriptBody>,
) -> Result<Json<ScriptRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    patch_script_inner(pool, uid, script_numeric_id, body, project_id).await
}

async fn patch_script_inner(
    pool: &PgPool,
    uid: Uuid,
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

    let oip = scope::owned_script_in_project(pool, uid, project_id, numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let current = sqlx::query_as::<_, ScriptRow>(
        r#"
        SELECT id, project_id, numeric_id, name, content, extract_state, create_time_ms
        FROM app_script
        WHERE id = $1
        "#,
    )
    .bind(oip.script_id)
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

pub(super) async fn delete_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let oip = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let res = sqlx::query(r#"DELETE FROM app_script WHERE id = $1"#)
        .bind(oip.script_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}
