use axum::{extract::State, http::HeaderMap, Json};
use chrono::Utc;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::AppState;

use super::storage::{delete_all_agent_memory_rows, ensure_project_owned, parse_agent_type};
use super::summarize::maybe_summarize_messages;
use super::types::{
    to_memory_history_item, AppendMemoryBody, AppendMemoryResponse, ClearMemoryBody,
    ClearMemoryResponse, MemoryHistoryItem, MessageRow, QueryMemoryBody,
};

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

    Ok(Json(rows.into_iter().map(to_memory_history_item).collect()))
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
