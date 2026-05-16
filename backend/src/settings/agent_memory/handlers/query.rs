use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::harness::observe;
use crate::state::AppState;

use super::super::storage::{parse_agent_type, resolve_agent_memory_project_numeric_id};
use super::super::types::{to_memory_history_item, MemoryHistoryItem, MessageRow, QueryMemoryBody};

fn memory_tier_requires_scope(memory_tier: &str) -> bool {
    matches!(memory_tier, "stage_summary" | "delta_memory")
}

fn scope_signature_has_any_dimension(scope_signature: &serde_json::Value) -> bool {
    let Some(object) = scope_signature.as_object() else {
        return false;
    };
    object.values().any(|value| match value {
        serde_json::Value::Null => false,
        serde_json::Value::Bool(_) => true,
        serde_json::Value::Number(_) => true,
        serde_json::Value::String(text) => !text.trim().is_empty(),
        serde_json::Value::Array(items) => !items.is_empty(),
        serde_json::Value::Object(map) => !map.is_empty(),
    })
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
    let agent_type = parse_agent_type(&body.agent_type)?;
    let memory_type = match body.memory_type.trim() {
        "" | "message" => "message",
        "summary" => "summary",
        "all" => "all",
        other => {
            return Err(bad_request_i18n(
                &format!("memoryType must be one of: message, summary, all (got {other})"),
                &format!("memoryType 必须是以下之一：message、summary、all（当前为 {other}）"),
            ));
        }
    };
    // 验证 memory_tier 过滤字段（如果提供）
    if let Some(ref tier) = body.memory_tier {
        if !crate::settings::agent_memory::memory_tier::MemoryTier::is_valid(tier.as_str()) {
            return Err(bad_request_i18n(
                "memoryTier must be one of: style_bible, stage_summary, delta_memory, message",
                "memoryTier 必须是以下之一：style_bible、stage_summary、delta_memory、message",
            ));
        }
        if memory_tier_requires_scope(tier)
            && !body
                .scope_signature
                .as_ref()
                .is_some_and(scope_signature_has_any_dimension)
        {
            return Err(bad_request_i18n(
                &format!("memoryTier {tier} requires a non-empty scopeSignature"),
                &format!("memoryTier {tier} 需要非空的 scopeSignature"),
            ));
        }
    } else if body
        .scope_signature
        .as_ref()
        .is_some_and(|scope| !scope_signature_has_any_dimension(scope))
    {
        return Err(bad_request_i18n(
            "scopeSignature must contain at least one scope dimension",
            "scopeSignature 至少需要包含一个范围维度",
        ));
    }
    if body.project_uuid.is_none() && body.project_id.is_none() {
        return Err(bad_request_i18n(
            "Provide projectUuid (preferred) or legacy numeric projectId",
            "请提供 projectUuid（推荐）或旧版数值 projectId",
        ));
    }
    let pool = state.require_pool()?;

    let numeric_project_id =
        resolve_agent_memory_project_numeric_id(pool, uid, body.project_uuid, body.project_id)
            .await?;
    observe::memory_http(uid, numeric_project_id, "query");

    let rows = if let Some(scope_signature) = body.scope_signature.as_ref() {
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
              AND scope_signature = $7
            ORDER BY create_time_ms ASC
            "#,
        )
        .bind(uid)
        .bind(numeric_project_id)
        .bind(agent_type)
        .bind(body.episodes_id)
        .bind(memory_type)
        .bind(&body.memory_tier)
        .bind(scope_signature)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
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
        .bind(numeric_project_id)
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

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::{memory_tier_requires_scope, scope_signature_has_any_dimension};

    #[test]
    fn scoped_query_tiers_require_scope_signature() {
        assert!(memory_tier_requires_scope("stage_summary"));
        assert!(memory_tier_requires_scope("delta_memory"));
        assert!(!memory_tier_requires_scope("style_bible"));
    }

    #[test]
    fn query_scope_signature_requires_meaningful_dimension() {
        assert!(scope_signature_has_any_dimension(
            &json!({"storyboardIds":[1], "episodeId": 2})
        ));
        assert!(!scope_signature_has_any_dimension(&json!({})));
        assert!(!scope_signature_has_any_dimension(
            &json!({"storyboardIds": [], "assetIds": []})
        ));
        assert!(!scope_signature_has_any_dimension(&json!("ep3")));
    }
}
