//! Q2 方案 B：`GET /api/v1/jobs/queue/stats` — 只读 PG 队列聚合（与 worker **`job_queue_metrics`** 同源 **`QueueStats`**）。
//!
//! 门禁：环境变量 **`TOONFLOW_INTERNAL_OPS_TOKEN`**（非空）；请求须带 **`X-Toonflow-Internal-Token`** 与之完全一致。
//! 未配置 token 时返回 **403**，避免意外暴露队列深度。

use axum::{extract::State, http::HeaderMap, Json};
use serde::Serialize;
use serde_json::Value;
use utoipa::ToSchema;

use crate::error::ApiError;
use crate::jobs::queue::{PgQueue, Queue};
use crate::state::AppState;

use super::common::require_pool;

#[derive(Debug, Serialize, ToSchema)]
pub struct JobQueueStatsResponse {
    pub pending: i64,
    pub pending_claimable: i64,
    pub running: i64,
    pub dead: i64,
    pub failed_last_24h: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub oldest_claimable_queued_age_secs: Option<i64>,
    pub pending_by_kind: Value,
}

fn internal_ops_token_expected() -> Option<String> {
    std::env::var("TOONFLOW_INTERNAL_OPS_TOKEN")
        .ok()
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
}

fn require_internal_ops_token(headers: &HeaderMap) -> Result<(), ApiError> {
    let Some(expected) = internal_ops_token_expected() else {
        return Err(ApiError::Forbidden(
            "job queue stats HTTP disabled (set TOONFLOW_INTERNAL_OPS_TOKEN)".into(),
        ));
    };
    let got = headers
        .get("x-toonflow-internal-token")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if got != expected.as_str() {
        return Err(ApiError::Unauthorized);
    }
    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/v1/jobs/queue/stats",
    operation_id = "getJobQueueStatsV1",
    tag = "jobs",
    responses(
        (status = 200, description = "OK", body = JobQueueStatsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody),
    )
)]
pub(crate) async fn get_job_queue_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<JobQueueStatsResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let pool = require_pool(&state)?;
    let queue = PgQueue::new(pool.clone());
    let stats = queue
        .stats()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(JobQueueStatsResponse {
        pending: stats.pending,
        pending_claimable: stats.pending_claimable,
        running: stats.running,
        dead: stats.dead,
        failed_last_24h: stats.failed_last_24h,
        oldest_claimable_queued_age_secs: stats.oldest_claimable_queued_age_secs,
        pending_by_kind: stats.pending_by_kind_json,
    }))
}
