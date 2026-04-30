use axum::{extract::State, http::HeaderMap, Json};
use serde::Serialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::storage::ensure_project_owned;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MemoryCostOverview {
    pub(crate) project_id: i32,
    pub(crate) style_bible_count: i64,
    pub(crate) stage_summary_count: i64,
    pub(crate) delta_memory_count: i64,
    pub(crate) message_count: i64,
    /// 近30次任务平均注入字数（近似：取最近30条记忆的平均 content 长度）
    pub(crate) avg_injected_chars_last30: i64,
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

    ensure_project_owned(pool, uid, params.project_id).await?;

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
    .bind(&params.agent_type)
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
    .bind(&params.agent_type)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(MemoryCostOverview {
        project_id: params.project_id,
        style_bible_count,
        stage_summary_count,
        delta_memory_count,
        message_count,
        avg_injected_chars_last30: avg_chars.unwrap_or(0),
    }))
}
