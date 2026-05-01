use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::AppState;

use super::super::storage::{ensure_project_owned, parse_agent_type};
use super::super::types::{to_memory_history_item, MemoryHistoryItem, MessageRow, QueryMemoryBody};

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
    let agent_type = parse_agent_type(&body.agent_type)?;
    let pool = state.require_pool()?;
    let memory_type = match body.memory_type.trim() {
        "" | "message" => "message",
        "summary" => "summary",
        "all" => "all",
        other => {
            return Err(ApiError::BadRequest(format!(
                "memoryType must be one of: message, summary, all (got {other})"
            )));
        }
    };
    // 验证 memory_tier 过滤字段（如果提供）
    if let Some(ref tier) = body.memory_tier {
        if !crate::settings::agent_memory::memory_tier::MemoryTier::is_valid(tier.as_str()) {
            return Err(ApiError::BadRequest(
                "memoryTier must be one of: style_bible, stage_summary, delta_memory, message"
                    .into(),
            ));
        }
    }

    ensure_project_owned(pool, uid, body.project_id).await?;
    observe::memory_http(uid, body.project_id, "query");

    let rows = if let Some(scope_signature) = body.scope_signature.as_ref() {
        let exact_rows = sqlx::query_as::<_, MessageRow>(
            r#"
            SELECT id, role, name, memory_tier, content, create_time_ms
            FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND agent_type = $3
              AND episodes_id IS NOT DISTINCT FROM $4
              AND ($5 = 'all' OR memory_type = $5)
              AND ($6::text IS NULL OR memory_tier = $6)
              AND scope_signature = $7
            ORDER BY create_time_ms ASC
            "#,
        )
        .bind(uid)
        .bind(body.project_id)
        .bind(agent_type)
        .bind(body.episodes_id)
        .bind(memory_type)
        .bind(&body.memory_tier)
        .bind(scope_signature)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if !exact_rows.is_empty() {
            exact_rows
        } else {
            sqlx::query_as::<_, MessageRow>(
                r#"
                SELECT id, role, name, memory_tier, content, create_time_ms
                FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND numeric_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND ($5 = 'all' OR memory_type = $5)
                  AND ($6::text IS NULL OR memory_tier = $6)
                ORDER BY create_time_ms ASC
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .bind(memory_type)
            .bind(&body.memory_tier)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        }
    } else {
        sqlx::query_as::<_, MessageRow>(
            r#"
            SELECT id, role, name, memory_tier, content, create_time_ms
            FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND agent_type = $3
              AND episodes_id IS NOT DISTINCT FROM $4
              AND ($5 = 'all' OR memory_type = $5)
              AND ($6::text IS NULL OR memory_tier = $6)
            ORDER BY create_time_ms ASC
            "#,
        )
        .bind(uid)
        .bind(body.project_id)
        .bind(agent_type)
        .bind(body.episodes_id)
        .bind(memory_type)
        .bind(&body.memory_tier)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };

    let items: Vec<MemoryHistoryItem> = rows.into_iter().map(to_memory_history_item).collect();

    Ok(Json(items))
}
