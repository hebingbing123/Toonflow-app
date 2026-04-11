//! 脚本 REST 路由（`GET`/`POST /api/v1/scripts/*` 与项目段脚本 API）。
//!
//! 脚本 CRUD、导出/抽取轮询、**`POST …/projects/{project_id}/scripts/get-script-api`** 列表等。

use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::Response,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{FromRow, PgPool, Postgres, QueryBuilder, Transaction};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::state::AppState;

#[derive(Debug, FromRow, Serialize)]
pub struct ScriptRow {
    pub id: Uuid,
    pub project_id: Uuid,
    #[serde(rename = "numeric_id")]
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

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CreateScriptBody {
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    content: Option<String>,
    #[serde(default)]
    extract_state: Option<i32>,
}

/// Body for **`POST …/projects/{project_id}/scripts/batch-add`** (project UUID in path).
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchAddScriptDataBody {
    data: Vec<BatchAddScriptItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchAddScriptItem {
    script_name: String,
    script_data: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BatchAddScriptResponse {
    message: String,
    inserted: i32,
    scripts: Vec<ScriptRow>,
}

/// Advisory lock key for allocating globally unique `app_script.legacy_id`.
const ADV_LOCK_SCRIPT_LEGACY_ID: i64 = 884_422_002;

/// Legacy `exportScript` accepted an array of ids; cap to bound work per request.
const MAX_SCRIPT_EXPORT: usize = 500;
/// Legacy `pollScriptAssets` polled many rows; cap list size.
const MAX_SCRIPT_EXTRACT_POLL: usize = 2_000;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct ExportScriptsBody {
    numeric_ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct ScriptExtractPollBody {
    numeric_ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
struct ScriptExtractPollRow {
    #[serde(rename = "numeric_id")]
    legacy_id: i32,
    extract_state: Option<i32>,
    error_reason: Option<String>,
}

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
        .bind(ADV_LOCK_SCRIPT_LEGACY_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
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
          project_id, legacy_id, name, content, extract_state, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
        RETURNING id, project_id, legacy_id, name, content, extract_state, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_legacy)
    .bind(trim_opt(body.name))
    .bind(trim_opt(body.content))
    .bind(body.extract_state)
    .bind(now_ms)
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

// ── `POST /api/v1/projects/{project_id}/scripts/get-script-api` ───────────────

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct GetScriptApiNameBody {
    #[serde(default)]
    name: Option<String>,
}

#[derive(Debug, FromRow)]
struct GetScriptApiScriptRow {
    id: Uuid,
    legacy_id: i32,
    name: Option<String>,
    content: Option<String>,
    extract_state: Option<i32>,
    error_reason: Option<String>,
    create_time_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
struct GetScriptApiRelatedAssetBrief {
    id: i32,
    name: String,
}

#[derive(Debug, Serialize)]
struct GetScriptApiScriptListItem {
    id: i32,
    name: Option<String>,
    content: Option<String>,
    #[serde(rename = "extractState")]
    extract_state: Option<i32>,
    #[serde(rename = "errorReason")]
    error_reason: Option<String>,
    #[serde(rename = "createTime")]
    create_time_ms: Option<i64>,
    #[serde(rename = "relatedAssets")]
    related_assets: Vec<GetScriptApiRelatedAssetBrief>,
}

#[derive(Debug, Serialize)]
struct GetScriptApiResponse {
    data: Vec<GetScriptApiScriptListItem>,
}

async fn get_script_api_for_project_uuid(
    pool: &PgPool,
    project_uuid: Uuid,
    name: Option<String>,
) -> Result<GetScriptApiResponse, ApiError> {
    let name_sub = name
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase());

    let scripts: Vec<GetScriptApiScriptRow> = if let Some(ref sub) = name_sub {
        sqlx::query_as::<_, GetScriptApiScriptRow>(
            r#"
            SELECT s.id, s.legacy_id, s.name, s.content, s.extract_state, s.error_reason, s.create_time_ms
            FROM app_script s
            WHERE s.project_id = $1
              AND s.name IS NOT NULL
              AND POSITION($2 IN LOWER(s.name)) > 0
            ORDER BY s.legacy_id ASC
            "#,
        )
        .bind(project_uuid)
        .bind(sub)
        .fetch_all(pool)
        .await
    } else {
        sqlx::query_as::<_, GetScriptApiScriptRow>(
            r#"
            SELECT s.id, s.legacy_id, s.name, s.content, s.extract_state, s.error_reason, s.create_time_ms
            FROM app_script s
            WHERE s.project_id = $1
            ORDER BY s.legacy_id ASC
            "#,
        )
        .bind(project_uuid)
        .fetch_all(pool)
        .await
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if scripts.is_empty() {
        return Ok(GetScriptApiResponse { data: vec![] });
    }

    let ids: Vec<Uuid> = scripts.iter().map(|s| s.id).collect();

    #[derive(Debug, FromRow)]
    struct GetScriptApiAssetLinkRow {
        script_id: Uuid,
        legacy_id: i32,
        name: String,
    }

    let links: Vec<GetScriptApiAssetLinkRow> = sqlx::query_as::<_, GetScriptApiAssetLinkRow>(
        r#"
        SELECT sa.script_id, a.legacy_id, a.name
        FROM app_script_asset sa
        INNER JOIN app_asset a ON a.id = sa.asset_id
        WHERE sa.script_id = ANY($1)
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(&ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut by_script: std::collections::HashMap<Uuid, Vec<GetScriptApiRelatedAssetBrief>> =
        std::collections::HashMap::new();
    for row in links {
        by_script
            .entry(row.script_id)
            .or_default()
            .push(GetScriptApiRelatedAssetBrief {
                id: row.legacy_id,
                name: row.name,
            });
    }

    let data = scripts
        .into_iter()
        .map(|s| {
            let related_assets = by_script.remove(&s.id).unwrap_or_default();
            GetScriptApiScriptListItem {
                id: s.legacy_id,
                name: s.name,
                content: s.content,
                extract_state: s.extract_state,
                error_reason: s.error_reason,
                create_time_ms: s.create_time_ms,
                related_assets,
            }
        })
        .collect();

    Ok(GetScriptApiResponse { data })
}

async fn post_get_script_api_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<GetScriptApiNameBody>,
) -> Result<Json<GetScriptApiResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let response = get_script_api_for_project_uuid(pool, project_id, body.name).await?;
    Ok(Json(response))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/scripts/export", post(export_scripts_zip))
        .route(
            "/api/v1/scripts/extract-state/poll",
            post(poll_script_extract_state),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts",
            post(create_script_under_project_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts/batch-add",
            post(post_scripts_batch_add_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts/{script_legacy_id}",
            get(get_script_for_project)
                .patch(patch_script_for_project)
                .delete(delete_script_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts/get-script-api",
            post(post_get_script_api_for_project),
        )
}

fn normalize_legacy_id_list(mut ids: Vec<i32>, max_len: usize) -> Result<Vec<i32>, ApiError> {
    ids.retain(|id| *id > 0);
    ids.sort_unstable();
    ids.dedup();
    if ids.is_empty() {
        return Err(ApiError::BadRequest(
            "numeric_ids must be non-empty (positive integers)".into(),
        ));
    }
    if ids.len() > max_len {
        return Err(ApiError::BadRequest(format!(
            "at most {max_len} numeric_ids per request"
        )));
    }
    Ok(ids)
}

fn zip_entry_name(legacy_id: i32, name: Option<&str>) -> String {
    let base_raw = name
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("script");
    let safe: String = base_raw
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '\0' | '\r' | '\n' => '_',
            c if c.is_control() => '_',
            c => c,
        })
        .take(180)
        .collect();
    let base = if safe.is_empty() {
        "script"
    } else {
        safe.as_str()
    };
    format!("{legacy_id}_{base}.txt")
}

fn build_scripts_zip(
    rows: Vec<(i32, Option<String>, Option<String>)>,
) -> Result<Vec<u8>, zip::result::ZipError> {
    use std::io::Write;
    use zip::write::FileOptions;
    use zip::{CompressionMethod, ZipWriter};

    let mut cursor = std::io::Cursor::new(Vec::new());
    {
        let mut zip = ZipWriter::new(&mut cursor);
        let options = FileOptions::default().compression_method(CompressionMethod::Deflated);
        for (legacy_id, name, content) in rows {
            let path = zip_entry_name(legacy_id, name.as_deref());
            zip.start_file(path, options)?;
            zip.write_all(content.unwrap_or_default().as_bytes())?;
        }
        zip.finish()?;
    }
    Ok(cursor.into_inner())
}

async fn export_scripts_zip(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExportScriptsBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let legacy_ids = normalize_legacy_id_list(body.numeric_ids, MAX_SCRIPT_EXPORT)?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT s.legacy_id, s.name, s.content
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = "#,
    );
    qb.push_bind(uid);
    qb.push(" AND s.legacy_id IN (");
    {
        let mut separated = qb.separated(", ");
        for id in &legacy_ids {
            separated.push_bind(*id);
        }
    }
    qb.push(") ORDER BY s.legacy_id");

    let rows: Vec<(i32, Option<String>, Option<String>)> = qb
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let bytes = tokio::task::spawn_blocking(move || build_scripts_zip(rows))
        .await
        .map_err(|e| {
            tracing::error!(error = %e, "scripts export zip task join");
            ApiError::Internal
        })?
        .map_err(|e: zip::result::ZipError| {
            tracing::error!(error = %e, "scripts export zip build");
            ApiError::Internal
        })?;

    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, "application/zip")
        .header(
            header::CONTENT_DISPOSITION,
            HeaderValue::from_static("attachment; filename=\"scripts.zip\""),
        )
        .body(Body::from(bytes))
        .map_err(|e| {
            tracing::error!(error = %e, "scripts export response headers");
            ApiError::Internal
        })
}

async fn poll_script_extract_state(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ScriptExtractPollBody>,
) -> Result<Json<Vec<ScriptExtractPollRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let legacy_ids = normalize_legacy_id_list(body.numeric_ids, MAX_SCRIPT_EXTRACT_POLL)?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT s.legacy_id, s.extract_state, s.error_reason
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = "#,
    );
    qb.push_bind(uid);
    qb.push(" AND s.legacy_id IN (");
    {
        let mut separated = qb.separated(", ");
        for id in &legacy_ids {
            separated.push_bind(*id);
        }
    }
    qb.push(") AND (s.extract_state IS DISTINCT FROM 0) ORDER BY s.legacy_id");

    let rows: Vec<ScriptExtractPollRow> = qb
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

async fn create_script_under_project_for_project(
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
        .bind(ADV_LOCK_SCRIPT_LEGACY_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut next_legacy: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
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
              project_id, legacy_id, name, content, extract_state, create_time_ms, metadata
            )
            VALUES ($1, $2, $3, $4, NULL, $5, '{}'::jsonb)
            RETURNING id, project_id, legacy_id, name, content, extract_state, create_time_ms
            "#,
        )
        .bind(project_uuid)
        .bind(next_legacy)
        .bind(item.script_name)
        .bind(item.script_data)
        .bind(now_ms)
        .fetch_one(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        inserted.push(row);
        next_legacy += 1;
    }

    Ok(BatchAddScriptResponse {
        message: "添加剧本成功".into(),
        inserted: i32::try_from(inserted.len()).unwrap_or(i32::MAX),
        scripts: inserted,
    })
}

async fn post_scripts_batch_add_for_project(
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

async fn get_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_legacy_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<ScriptRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let row = sqlx::query_as::<_, ScriptRow>(
        r#"
        SELECT s.id, s.project_id, s.legacy_id, s.name, s.content, s.extract_state, s.create_time_ms
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE s.legacy_id = $1 AND p.id = $2 AND p.owner_user_id = $3
        "#,
    )
    .bind(script_legacy_id)
    .bind(project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn patch_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_legacy_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchScriptBody>,
) -> Result<Json<ScriptRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    patch_script_inner(pool, uid, script_legacy_id, body, project_id).await
}

async fn patch_script_inner(
    pool: &PgPool,
    uid: Uuid,
    legacy_id: i32,
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
        SELECT s.id, s.project_id, s.legacy_id, s.name, s.content, s.extract_state, s.create_time_ms
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE s.legacy_id = $1 AND p.id = $2 AND p.owner_user_id = $3
        "#,
    )
    .bind(legacy_id)
    .bind(project_id)
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

async fn delete_script_for_project(
    State(state): State<AppState>,
    Path((project_id, script_legacy_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_script s
        USING app_project p
        WHERE s.project_id = p.id
          AND s.legacy_id = $1
          AND p.owner_user_id = $2
          AND p.id = $3
        "#,
    )
    .bind(script_legacy_id)
    .bind(uid)
    .bind(project_id)
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
    fn patch_script_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<PatchScriptBody>(r#"{"name":"a","extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_script_body_accepts_empty() {
        let b: CreateScriptBody = serde_json::from_str("{}").unwrap();
        assert!(b.name.is_none());
    }

    #[test]
    fn create_script_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CreateScriptBody>(r#"{"name":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn batch_add_script_data_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<BatchAddScriptDataBody>(r#"{"data":[],"extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn export_scripts_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<ExportScriptsBody>(r#"{"numeric_ids":[1],"x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn zip_entry_name_sanitizes_path_chars() {
        assert_eq!(super::zip_entry_name(3, Some("a/b")), "3_a_b.txt");
        assert_eq!(super::zip_entry_name(1, None), "1_script.txt");
    }

    #[test]
    fn build_scripts_zip_roundtrip() {
        let rows = vec![(1, Some("n".into()), Some("hello".into())), (2, None, None)];
        let zip_bytes = super::build_scripts_zip(rows).expect("zip");
        assert!(zip_bytes.len() > 20);
    }
}
