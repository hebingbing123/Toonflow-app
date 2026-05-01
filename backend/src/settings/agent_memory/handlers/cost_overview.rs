use axum::{extract::State, http::HeaderMap, Json};
use serde::Serialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::{
    load_project_automation_memory_policy, load_project_memory_budget_snapshot,
    storage::{ensure_project_owned, parse_agent_type},
};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MemoryCostOverview {
    pub(crate) project_id: i32,
    pub(crate) automation_mode: String,
    pub(crate) style_bible_count: i64,
    pub(crate) stage_summary_count: i64,
    pub(crate) delta_memory_count: i64,
    pub(crate) message_count: i64,
    /// 近30次任务平均注入字数（近似：取最近30条记忆的平均 content 长度）
    pub(crate) avg_injected_chars_last30: i64,
    /// 近30条记忆涉及的平均命中层级数（近似：取最近30条内的 distinct tier 数）
    pub(crate) avg_hit_tier_count_last30: i64,
    pub(crate) low_value_memory_ratio_percent: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) last_injected_at: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CostOverviewQuery {
    pub(crate) project_id: i32,
    pub(crate) agent_type: String,
}

#[utoipa::path(
    get,
    path = "/api/v1/agents/memory/cost-overview",
    operation_id = "getMemoryCostOverviewV1",
    tag = "agents",
    params(
        ("projectId" = i32, Query, description = "Project ID"),
        ("agentType" = String, Query, description = "Agent type"),
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_memory_cost_overview(
    State(state): State<AppState>,
    headers: HeaderMap,
    axum::extract::Query(params): axum::extract::Query<CostOverviewQuery>,
) -> Result<Json<MemoryCostOverview>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let agent_type = parse_agent_type(&params.agent_type)?;

    ensure_project_owned(pool, uid, params.project_id).await?;
    let policy =
        load_project_automation_memory_policy(pool, uid, params.project_id, agent_type).await?;
    let budget_snapshot =
        load_project_memory_budget_snapshot(pool, uid, params.project_id, agent_type).await?;

    // 各层记忆条目数
    let counts: Vec<(String, i64)> = sqlx::query_as(
        r#"
        SELECT memory_tier, COUNT(*)::bigint as cnt
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = $3
        GROUP BY memory_tier
        "#,
    )
    .bind(uid)
    .bind(params.project_id)
    .bind(agent_type)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut style_bible_count = 0i64;
    let mut stage_summary_count = 0i64;
    let mut delta_memory_count = 0i64;
    let mut message_count = 0i64;

    for (tier, cnt) in counts {
        match tier.as_str() {
            "style_bible" => style_bible_count = cnt,
            "stage_summary" => stage_summary_count = cnt,
            "delta_memory" => delta_memory_count = cnt,
            _ => message_count += cnt,
        }
    }

    // 近30条记忆的平均 content 长度
    let avg_chars: Option<i64> = sqlx::query_scalar(
        r#"
        SELECT AVG(char_length(content))::bigint
        FROM (
            SELECT content
            FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND agent_type = $3
            ORDER BY create_time_ms DESC
            LIMIT 30
        ) sub
        "#,
    )
    .bind(uid)
    .bind(params.project_id)
    .bind(agent_type)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let distinct_tier_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(DISTINCT COALESCE(memory_tier, 'message'))::bigint
        FROM (
            SELECT memory_tier
            FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND agent_type = $3
            ORDER BY create_time_ms DESC
            LIMIT 30
        ) sub
        "#,
    )
    .bind(uid)
    .bind(params.project_id)
    .bind(agent_type)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let last_injected_at: Option<String> = sqlx::query_scalar(
        r#"
        SELECT to_char(
            to_timestamp(MAX(create_time_ms) / 1000.0) AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
        )
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = $3
        "#,
    )
    .bind(uid)
    .bind(params.project_id)
    .bind(agent_type)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(MemoryCostOverview {
        project_id: params.project_id,
        automation_mode: policy.mode.as_str().to_string(),
        style_bible_count,
        stage_summary_count,
        delta_memory_count,
        message_count,
        avg_injected_chars_last30: avg_chars.unwrap_or(0),
        avg_hit_tier_count_last30: distinct_tier_count,
        low_value_memory_ratio_percent: budget_snapshot.low_value_ratio_percent(),
        last_injected_at,
    }))
}
