use axum::{extract::State, http::HeaderMap, Json};
use chrono::Utc;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::AppState;

use super::super::storage::{ensure_project_owned, parse_agent_type};
use super::super::summarize::maybe_summarize_messages;
use super::super::types::{AppendMemoryBody, AppendMemoryResponse};

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
