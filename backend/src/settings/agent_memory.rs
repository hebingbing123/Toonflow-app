//! 代理每项目记忆（`app_agent_memory`）。
//!
//! 与遗留 SQLite `memories` + HTTP `/api/agents/getMemory` / `/api/agents/clearMemory` 兼容（驼峰式 JSON 请求体）。

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
    /// `all` | `message` | `summary` — same semantics as Electron-era `clearMemory` (`type` in old API).
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
pub(crate) struct ContentBlock {
    #[serde(rename = "type")]
    block_type: &'static str,
    status: &'static str,
    data: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MemoryHistoryItem {
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
pub(crate) struct AppendMemoryResponse {
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
    numeric_project_id: i32,
) -> Result<(), ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_project
          WHERE numeric_id = $1 AND owner_user_id = $2
        )
        "#,
    )
    .bind(numeric_project_id)
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
          AND numeric_project_id = $2
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

#[utoipa::path(
    post,
    path = "/api/v1/agents/memory/query",
    operation_id = "queryAgentMemoryV1",
    tag = "agents",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn query_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<QueryMemoryBody>,
) -> Result<Json<Vec<MemoryHistoryItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let agent_type = parse_agent_type(&body.agent_type)?;

    ensure_project_owned(pool, uid, body.project_id).await?;

    observe::memory_http(uid, body.project_id, "query");

    let rows = sqlx::query_as::<_, MessageRow>(
        r#"
        SELECT id, role, name, content, create_time_ms
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
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

#[utoipa::path(
    post,
    path = "/api/v1/agents/memory/clear",
    operation_id = "clearAgentMemoryV1",
    tag = "agents",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn clear_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ClearMemoryBody>,
) -> Result<Json<ClearMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
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
                  AND numeric_project_id = $2
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
                  AND numeric_project_id = $2
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
                  AND numeric_project_id = $2
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
                  AND numeric_project_id = $2
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

#[utoipa::path(
    post,
    path = "/api/v1/agents/memory/append",
    operation_id = "appendAgentMemoryV1",
    tag = "agents",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn append_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AppendMemoryBody>,
) -> Result<Json<AppendMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
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
          owner_user_id, numeric_project_id, episodes_id, agent_type,
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

    // Trigger async summarization if threshold reached
    let messages_per_summary = state.memory_config.read().await.messages_per_summary;
    let pool_clone = pool.clone();
    let state_clone = state.clone();
    let uid_clone = uid;
    let project_id = body.project_id;
    let episodes_id = body.episodes_id;
    let agent_type_str = agent_type.to_string();
    tokio::spawn(async move {
        if let Err(e) = maybe_summarize_messages(
            &pool_clone,
            &state_clone,
            uid_clone,
            project_id,
            episodes_id,
            &agent_type_str,
            messages_per_summary,
        )
        .await
        {
            tracing::warn!(error = %e, "auto-summarization failed");
        }
    });

    Ok(Json(AppendMemoryResponse { id: id.to_string() }))
}

/// Check if summarization is needed and generate summary via LLM
async fn maybe_summarize_messages(
    pool: &PgPool,
    state: &AppState,
    uid: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    messages_per_summary: i64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    // Count unsummarized messages
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'message'
          AND summarized = 0
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .fetch_one(pool)
    .await?;

    if count < messages_per_summary {
        return Ok(());
    }

    // Fetch messages to summarize (oldest first, up to messages_per_summary)
    let messages: Vec<(String, String)> = sqlx::query_as(
        r#"
        SELECT role, content FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'message'
          AND summarized = 0
        ORDER BY create_time_ms ASC
        LIMIT $5
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(messages_per_summary)
    .fetch_all(pool)
    .await?;

    if messages.is_empty() {
        return Ok(());
    }

    // Build conversation text for summarization
    let conversation = messages
        .iter()
        .map(|(role, content)| format!("{}: {}", role, content))
        .collect::<Vec<_>>()
        .join("\n");

    // Generate summary via LLM if configured
    let summary_text = if let Some(ref cfg) = state.llm {
        let client = reqwest::Client::new();
        let prompt = format!(
            "请总结以下对话的关键要点，用中文输出，不超过100字：\n\n{}",
            conversation
        );
        let llm_messages = vec![
            serde_json::json!({"role": "system", "content": "你是一个对话摘要助手。"}),
            serde_json::json!({"role": "user", "content": prompt}),
        ];
        match crate::llm::chat_completion_assistant_text(cfg, &client, llm_messages).await {
            Ok(text) => text,
            Err(e) => {
                tracing::warn!(error = %e, "LLM summarization failed, using fallback");
                format!("[摘要] {}条消息待总结", messages.len())
            }
        }
    } else {
        format!("[摘要] {}条消息待总结", messages.len())
    };

    let summary_max_length = state.memory_config.read().await.summary_max_length as usize;
    let summary_text = if summary_text.len() > summary_max_length {
        format!(
            "{}...",
            &summary_text[..summary_max_length.min(summary_text.len()) - 3]
        )
    } else {
        summary_text
    };

    let now_ms = Utc::now().timestamp_millis();

    // Insert summary record
    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, 'summary', 'assistant', 'summary', $5, 1, $6)
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(&summary_text)
    .bind(now_ms)
    .execute(pool)
    .await?;

    // Mark messages as summarized
    sqlx::query(
        r#"
        UPDATE app_agent_memory
        SET summarized = 1
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'message'
          AND summarized = 0
          AND id IN (
            SELECT id FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND episodes_id IS NOT DISTINCT FROM $3
              AND agent_type = $4
              AND memory_type = 'message'
              AND summarized = 0
            ORDER BY create_time_ms ASC
            LIMIT $5
          )
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(messages_per_summary)
    .execute(pool)
    .await?;

    tracing::info!(
        user_id = %uid,
        project_id = %project_id,
        agent_type = %agent_type,
        "auto-generated memory summary"
    );

    Ok(())
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
    fn clear_accepts_type_field_alias() {
        let b: ClearMemoryBody =
            serde_json::from_str(r#"{"projectId":1,"agentType":"scriptAgent","type":"message"}"#)
                .unwrap();
        assert_eq!(b.clear_type, "message");
    }
}
