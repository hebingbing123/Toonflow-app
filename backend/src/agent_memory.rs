//! Agent per-project memory (`app_agent_memory`). Parity with legacy SQLite `memories` + HTTP
//! `/api/agents/getMemory` / `/api/agents/clearMemory` (camelCase JSON bodies).

use axum::{extract::State, http::HeaderMap, routing::post, Json, Router};
use chrono::{TimeZone, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QueryMemoryBody {
    pub project_id: i32,
    pub agent_type: String,
    #[serde(default)]
    pub episodes_id: Option<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClearMemoryBody {
    pub project_id: i32,
    pub agent_type: String,
    #[serde(default)]
    pub episodes_id: Option<i32>,
    /// `all` | `message` | `summary` — same semantics as legacy `clearMemory` (`type` in old API).
    #[serde(default = "default_clear_kind", alias = "type")]
    pub clear_type: String,
}

fn default_clear_kind() -> String {
    "all".to_string()
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppendMemoryBody {
    pub project_id: i32,
    pub agent_type: String,
    #[serde(default)]
    pub episodes_id: Option<i32>,
    #[serde(default = "default_role")]
    pub role: String,
    pub content: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub create_time: Option<i64>,
}

fn default_role() -> String {
    "user".to_string()
}

#[derive(Debug, FromRow)]
struct MessageRow {
    id: Uuid,
    role: Option<String>,
    name: Option<String>,
    content: String,
    create_time_ms: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ContentBlock {
    #[serde(rename = "type")]
    block_type: &'static str,
    status: &'static str,
    data: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MemoryHistoryItem {
    id: String,
    role: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    name: Option<String>,
    status: &'static str,
    datetime: String,
    content: Vec<ContentBlock>,
    create_time: i64,
}

#[derive(Serialize)]
struct AppendMemoryResponse {
    id: String,
}

#[derive(Serialize)]
pub(crate) struct ClearMemoryResponse {
    pub(crate) ok: bool,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/agents/memory/query", post(query_memory))
        .route("/api/v1/agents/memory/clear", post(clear_memory))
        .route("/api/v1/agents/memory/append", post(append_memory))
}

pub(crate) fn parse_agent_type(raw: &str) -> Result<&'static str, ApiError> {
    match raw {
        "scriptAgent" => Ok("scriptAgent"),
        "productionAgent" => Ok("productionAgent"),
        _ => Err(ApiError::BadRequest(
            "agentType must be scriptAgent or productionAgent".into(),
        )),
    }
}

fn normalize_role(role: Option<String>) -> String {
    match role {
        Some(r) if r.starts_with("assistant") => "assistant".to_string(),
        _ => "user".to_string(),
    }
}

pub(crate) async fn ensure_project_owned(
    pool: &PgPool,
    uid: Uuid,
    legacy_project_id: i32,
) -> Result<(), ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_project
          WHERE legacy_id = $1 AND owner_user_id = $2
        )
        "#,
    )
    .bind(legacy_project_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !ok {
        return Err(ApiError::NotFound);
    }
    Ok(())
}

/// Same **`DELETE`** scope as **`POST /api/v1/agents/memory/clear`** with **`clearType: all`**.
pub(crate) async fn delete_all_agent_memory_rows(
    tx: &mut Transaction<'_, Postgres>,
    uid: Uuid,
    project_id: i32,
    agent_type: &'static str,
    episodes_id: Option<i32>,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND legacy_project_id = $2
          AND agent_type = $3
          AND episodes_id IS NOT DISTINCT FROM $4
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(agent_type)
    .bind(episodes_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn query_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<QueryMemoryBody>,
) -> Result<Json<Vec<MemoryHistoryItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let agent_type = parse_agent_type(&body.agent_type)?;

    ensure_project_owned(pool, uid, body.project_id).await?;

    observe::memory_http(uid, body.project_id, "query");

    let rows = sqlx::query_as::<_, MessageRow>(
        r#"
        SELECT id, role, name, content, create_time_ms
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND legacy_project_id = $2
          AND agent_type = $3
          AND episodes_id IS NOT DISTINCT FROM $4
          AND memory_type = 'message'
        ORDER BY create_time_ms ASC
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(agent_type)
    .bind(body.episodes_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut out = Vec::with_capacity(rows.len());
    for row in rows {
        let dt = Utc
            .timestamp_millis_opt(row.create_time_ms)
            .single()
            .unwrap_or_else(Utc::now);
        out.push(MemoryHistoryItem {
            id: row.id.to_string(),
            role: normalize_role(row.role),
            name: row.name,
            status: "complete",
            datetime: dt.to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
            content: vec![ContentBlock {
                block_type: "markdown",
                status: "complete",
                data: row.content,
            }],
            create_time: row.create_time_ms,
        });
    }

    Ok(Json(out))
}

async fn clear_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ClearMemoryBody>,
) -> Result<Json<ClearMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let agent_type = parse_agent_type(&body.agent_type)?;

    ensure_project_owned(pool, uid, body.project_id).await?;

    observe::memory_http(uid, body.project_id, "clear");

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    match body.clear_type.as_str() {
        "all" => {
            delete_all_agent_memory_rows(
                &mut tx,
                uid,
                body.project_id,
                agent_type,
                body.episodes_id,
            )
            .await?;
        }
        "message" => {
            sqlx::query(
                r#"
                DELETE FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND legacy_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND memory_type = 'message'
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            sqlx::query(
                r#"
                DELETE FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND legacy_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND memory_type = 'summary'
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
        "summary" => {
            sqlx::query(
                r#"
                UPDATE app_agent_memory
                SET summarized = 0
                WHERE owner_user_id = $1
                  AND legacy_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND memory_type = 'message'
                  AND summarized = 1
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            sqlx::query(
                r#"
                DELETE FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND legacy_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND memory_type = 'summary'
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
        _ => {
            return Err(ApiError::BadRequest(
                "clearType must be all, message, or summary".into(),
            ));
        }
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ClearMemoryResponse { ok: true }))
}

async fn append_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AppendMemoryBody>,
) -> Result<Json<AppendMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let agent_type = parse_agent_type(&body.agent_type)?;

    if body.content.trim().is_empty() {
        return Err(ApiError::BadRequest("content must be non-empty".into()));
    }

    ensure_project_owned(pool, uid, body.project_id).await?;

    observe::memory_http(uid, body.project_id, "append");

    let create_time_ms = body
        .create_time
        .unwrap_or_else(|| Utc::now().timestamp_millis());

    let id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, legacy_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, 'message', $5, $6, $7, 0, $8)
        RETURNING id
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.episodes_id)
    .bind(agent_type)
    .bind(&body.role)
    .bind(&body.name)
    .bind(&body.content)
    .bind(create_time_ms)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(AppendMemoryResponse { id: id.to_string() }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn query_body_accepts_camel_case() {
        let b: QueryMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"scriptAgent","episodesId":2}"#)
                .unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.agent_type, "scriptAgent");
        assert_eq!(b.episodes_id, Some(2));
    }

    #[test]
    fn clear_defaults_to_all() {
        let b: ClearMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"productionAgent"}"#).unwrap();
        assert_eq!(b.clear_type, "all");
    }

    #[test]
    fn clear_accepts_legacy_type_field() {
        let b: ClearMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"scriptAgent","type":"message"}"#)
                .unwrap();
        assert_eq!(b.clear_type, "message");
    }
}
