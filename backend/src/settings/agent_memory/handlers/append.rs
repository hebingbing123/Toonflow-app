use axum::{extract::State, http::HeaderMap, Json};
use chrono::Utc;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::AppState;

use super::super::memory_tier::MemoryTier;
use super::super::storage::{parse_agent_type, resolve_agent_memory_project_numeric_id};
use super::super::summarize::maybe_summarize_messages;
use super::super::types::{AppendMemoryBody, AppendMemoryResponse};

fn scope_signature_has_any_dimension(scope_signature: &serde_json::Value) -> bool {
    let Some(object) = scope_signature.as_object() else {
        return false;
    };
    object.values().any(|value| match value {
        serde_json::Value::Null => false,
        serde_json::Value::String(text) => !text.trim().is_empty(),
        serde_json::Value::Array(items) => !items.is_empty(),
        serde_json::Value::Object(map) => !map.is_empty(),
        serde_json::Value::Bool(flag) => *flag,
        serde_json::Value::Number(_) => true,
    })
}

fn memory_tier_requires_scope(memory_tier: &str) -> bool {
    matches!(memory_tier, "stage_summary" | "delta_memory")
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
    if body.content.trim().is_empty() {
        return Err(ApiError::BadRequest("content must be non-empty".into()));
    }
    if !matches!(body.memory_type.as_str(), "message" | "summary") {
        return Err(ApiError::BadRequest(
            "memoryType must be message or summary".into(),
        ));
    }
    // 验证 memory_tier（如果提供）
    if let Some(ref tier) = body.memory_tier {
        if !MemoryTier::is_valid(tier.as_str()) {
            return Err(ApiError::BadRequest(
                "memoryTier must be one of: style_bible, stage_summary, delta_memory, message"
                    .into(),
            ));
        }
    }
    let memory_tier = body.memory_tier.as_deref().unwrap_or("message");
    if memory_tier_requires_scope(memory_tier)
        && !body
            .scope_signature
            .as_ref()
            .is_some_and(scope_signature_has_any_dimension)
    {
        return Err(ApiError::BadRequest(format!(
            "memoryTier {memory_tier} requires a non-empty scopeSignature"
        )));
    }
    let agent_type = parse_agent_type(&body.agent_type)?;
    if body.project_uuid.is_none() && body.project_id.is_none() {
        return Err(ApiError::BadRequest(
            "Provide projectUuid (preferred) or legacy numeric projectId".into(),
        ));
    }
    let pool = state.require_pool()?;

    let numeric_project_id =
        resolve_agent_memory_project_numeric_id(pool, uid, body.project_uuid, body.project_id)
            .await?;
    observe::memory_http(uid, numeric_project_id, "append");

    let create_time_ms = body
        .create_time
        .unwrap_or_else(|| Utc::now().timestamp_millis());

    let summarized = if body.memory_type == "summary" { 1 } else { 0 };

    let id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms,
          memory_tier, scope_signature
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING id
        "#,
    )
    .bind(uid)
    .bind(numeric_project_id)
    .bind(body.episodes_id)
    .bind(agent_type)
    .bind(&body.memory_type)
    .bind(&body.role)
    .bind(&body.name)
    .bind(&body.content)
    .bind(summarized)
    .bind(create_time_ms)
    .bind(memory_tier)
    .bind(&body.scope_signature)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if body.memory_type == "message" {
        let messages_per_summary = state.memory_config.read().await.messages_per_summary;
        let pool_clone = pool.clone();
        let state_clone = state.clone();
        let uid_clone = uid;
        let project_id = numeric_project_id;
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
    }

    Ok(Json(AppendMemoryResponse { id: id.to_string() }))
}

#[cfg(test)]
mod tests {
    use super::{memory_tier_requires_scope, scope_signature_has_any_dimension};
    use serde_json::json;

    #[test]
    fn scoped_tiers_require_scope_signature() {
        assert!(memory_tier_requires_scope("stage_summary"));
        assert!(memory_tier_requires_scope("delta_memory"));
        assert!(!memory_tier_requires_scope("style_bible"));
        assert!(!memory_tier_requires_scope("message"));
    }

    #[test]
    fn scope_signature_requires_meaningful_dimension() {
        assert!(scope_signature_has_any_dimension(
            &json!({"episodeId": 3, "focusSections": ["ep3-sc2"]})
        ));
        assert!(!scope_signature_has_any_dimension(&json!({})));
        assert!(!scope_signature_has_any_dimension(
            &json!({"episodeId": null, "focusSections": []})
        ));
        assert!(!scope_signature_has_any_dimension(&json!("ep3")));
    }
}
