// Feature: ai-drama-quality-optimization
//! 局部返工（Patch Regeneration）模块（需求 35.1, 35.2, 35.4, 35.7）
//!
//! 提供 `POST /api/v1/production/patch` 端点，支持对失败的集、场、分镜、
//! 视频提示词或衍生资产做定点重生成，不整段重跑。

pub mod dispatch;
pub mod models;

use axum::{extract::State, http::HeaderMap, Json};
use chrono::Utc;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::settings::agent_memory::{
    ensure_project_owned, replace_named_summary_memory_with_scope,
};
use crate::state::AppState;

use models::{ModelTier, PatchAttempt, PatchRequest, PatchResponse, PatchScope};

#[derive(Debug, sqlx::FromRow)]
struct PatchAttemptMemoryRow {
    content: String,
}

fn patch_attempt_name(scope: &PatchScope) -> String {
    format!("patch_attempt:{}", scope.label())
}

fn patch_scope_signature(scope: &PatchScope, ids: &[i64]) -> serde_json::Value {
    json!({
        "patchScope": scope,
        "targetIds": ids,
    })
}

async fn load_patch_history(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    scope: &PatchScope,
) -> Result<Vec<PatchAttempt>, ApiError> {
    let rows = sqlx::query_as::<_, PatchAttemptMemoryRow>(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND memory_tier = 'delta_memory'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT 8
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(patch_attempt_name(scope))
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .filter_map(|row| serde_json::from_str::<serde_json::Value>(&row.content).ok())
        .filter_map(|value| {
            let scope = serde_json::from_value::<PatchScope>(value.get("scope")?.clone()).ok()?;
            let ids = value
                .get("ids")?
                .as_array()?
                .iter()
                .filter_map(|item| item.as_i64())
                .collect::<Vec<_>>();
            let reason = value.get("reason")?.as_str()?.to_string();
            let model_tier =
                serde_json::from_value::<ModelTier>(value.get("modelTier")?.clone()).ok()?;
            let succeeded = value
                .get("succeeded")
                .and_then(|item| item.as_bool())
                .unwrap_or(false);
            Some(PatchAttempt {
                scope,
                ids,
                reason,
                model_tier,
                succeeded,
            })
        })
        .collect())
}

async fn persist_patch_attempt(
    pool: &PgPool,
    user_id: Uuid,
    request: &PatchRequest,
) -> Result<(), ApiError> {
    let content = serde_json::to_string(&json!({
        "scope": request.scope,
        "ids": request.ids,
        "reason": request.reason,
        "modelTier": request.model_tier,
        "succeeded": false,
    }))
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;
    let signature = patch_scope_signature(&request.scope, &request.ids);

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms,
          memory_tier, scope_signature
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, $6, 'delta_memory', $7)
        "#,
    )
    .bind(user_id)
    .bind(request.project_id)
    .bind(request.episodes_id)
    .bind(patch_attempt_name(&request.scope))
    .bind(content)
    .bind(Utc::now().timestamp_millis())
    .bind(signature)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

async fn persist_attribution_memory(
    pool: &PgPool,
    user_id: Uuid,
    request: &PatchRequest,
    response: &PatchResponse,
) -> Result<bool, ApiError> {
    if !response.attribution_mode {
        return Ok(false);
    }
    let Some(category) = response.attribution_category.as_deref() else {
        return Ok(false);
    };
    let Some(summary) = response.attribution_summary.as_deref() else {
        return Ok(false);
    };
    let scope_key = request
        .ids
        .iter()
        .map(i64::to_string)
        .collect::<Vec<_>>()
        .join("_");
    let name = format!("patch_attribution:{}:{}", category, scope_key);
    let signature = patch_scope_signature(&request.scope, &request.ids);
    let content = serde_json::to_string(&json!({
        "scope": request.scope,
        "targetIds": request.ids,
        "category": category,
        "summary": summary,
        "repairPriority": response.repair_priority,
        "savedTokenEstimate": response.saved_token_estimate,
        "suggestedUpstreamStage": response.suggested_upstream_stage,
        "suggestedUpstreamScope": response.suggested_upstream_scope,
    }))
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    replace_named_summary_memory_with_scope(
        pool,
        user_id,
        request.project_id,
        request.episodes_id,
        "productionAgent",
        "assistant",
        &name,
        &content,
        "delta_memory",
        Some(&signature),
        None,
    )
    .await?;

    Ok(true)
}

/// `POST /api/v1/production/patch`
///
/// 局部返工端点。接受返工粒度、目标 ID 列表、原因和模型层级，
/// 返回返工任务信息（含是否进入归因模式）。
///
/// 注意：本端点当前实现为「派发层」——验证请求、判断归因模式、返回任务元数据。
/// 实际的 Agent 重生成调用由 Harness WebSocket 层异步执行。
pub async fn post_production_patch(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PatchRequest>,
) -> Result<Json<PatchResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    ensure_project_owned(pool, uid, body.project_id).await?;

    // 验证 reason 非空
    if body.reason.trim().is_empty() {
        return Err(ApiError::BadRequest(
            "reason 不能为空，请说明返工原因".into(),
        ));
    }

    let history =
        load_patch_history(pool, uid, body.project_id, body.episodes_id, &body.scope).await?;
    let mut response =
        dispatch::build_patch_response(&body, &history).map_err(ApiError::BadRequest)?;
    response.memory_written = persist_attribution_memory(pool, uid, &body, &response).await?;
    persist_patch_attempt(pool, uid, &body).await?;

    Ok(Json(response))
}
