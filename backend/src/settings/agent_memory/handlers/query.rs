use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::AppState;

use super::super::storage::{compress_memory_results, ensure_project_owned, parse_agent_type};
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

    let rows = sqlx::query_as::<_, MessageRow>(
        r#"
        SELECT id, role, name, content, create_time_ms
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items: Vec<MemoryHistoryItem> = rows.into_iter().map(to_memory_history_item).collect();

    // 需求 33.7：命中条目 > 3 条时压缩为结构化摘要，减少注入 token 消耗
    // 压缩后直接替换原始列表，避免 Agent 处理过多历史上下文
    if items.len() > 3 {
        let contents: Vec<String> = items
            .iter()
            .map(|i| {
                i.content
                    .first()
                    .map(|b| b.data.clone())
                    .unwrap_or_default()
            })
            .collect();
        if let Some(compressed) = compress_memory_results(contents) {
            let compressed_str = serde_json::to_string_pretty(&compressed).unwrap_or_default();
            tracing::debug!(
                user_id = %uid,
                project_id = %body.project_id,
                original_count = items.len(),
                "memory results compressed to reduce token injection"
            );
            // 返回单条压缩摘要，替换原始列表
            let summary_item = MemoryHistoryItem {
                id: "compressed_summary".to_string(),
                role: "assistant".to_string(),
                name: Some("memory_compression".to_string()),
                status: "complete",
                datetime: chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
                content: vec![super::super::types::ContentBlock {
                    block_type: "markdown",
                    status: "complete",
                    data: format!("[记忆压缩摘要 - 原始{}条]\n{}", items.len(), compressed_str),
                }],
                create_time: chrono::Utc::now().timestamp_millis(),
            };
            return Ok(Json(vec![summary_item]));
        }
    }

    Ok(Json(items))
}
