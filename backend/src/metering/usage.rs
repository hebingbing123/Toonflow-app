//! 使用计量（`app_usage_event`，§12.3）：记录服务器端结果并公开每个用户的计数。

use std::collections::HashMap;

use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::get;
use axum::{Json, Router};
use serde::Serialize;
use serde_json::json;
use sqlx::PgPool;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::quota;
use crate::state::AppState;

/// Called when a generation job reaches `succeeded` (best-effort; failures are logged only).
pub async fn record_generation_job_succeeded(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
) -> Result<(), sqlx::Error> {
    record_job_event(pool, user_id, job_id, job_kind, "generation_job.succeeded").await
}

/// Called when a new generation job is created (best-effort; used for quota audit trail).
pub async fn record_generation_job_created(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
) -> Result<(), sqlx::Error> {
    record_job_event(pool, user_id, job_id, job_kind, "generation_job.created").await
}

async fn record_job_event(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
    event_type: &str,
) -> Result<(), sqlx::Error> {
    let payload = json!({ "kind": job_kind });
    sqlx::query(
        r#"
        INSERT INTO app_usage_event (user_id, event_type, source_job_id, payload)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(user_id)
    .bind(event_type)
    .bind(job_id)
    .bind(payload)
    .execute(pool)
    .await?;
    Ok(())
}

#[derive(Serialize, ToSchema)]
struct UsageSummaryResponse {
    events_last_24h: i64,
    events_last_7d: i64,
    /// Per-`event_type` counts in the rolling last 7 days (same window as `events_last_7d`).
    event_counts_last_7d: HashMap<String, i64>,
    /// Jobs created today (UTC natural day) — same counter used by quota enforcement.
    jobs_today: i64,
    /// Effective daily job cap for this user (`null` = unlimited).
    daily_job_quota: Option<i64>,
    /// Remaining jobs allowed today (`null` = unlimited). `0` means quota is exhausted.
    #[serde(skip_serializing_if = "Option::is_none")]
    quota_remaining: Option<i64>,
}

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/usage/summary", get(usage_summary))
}

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(usage_summary),
    components(schemas(UsageSummaryResponse, crate::error::ErrorBody)),
    tags((name = "usage", description = "Per-user usage and quota hints"))
)]
pub struct MeteringOpenApi;

#[utoipa::path(
    get,
    path = "/api/v1/usage/summary",
    operation_id = "usageSummaryV1",
    tag = "usage",
    responses(
        (status = 200, description = "OK", body = UsageSummaryResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
async fn usage_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<UsageSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // Event counts (24h / 7d).
    let row: (i64, i64) = sqlx::query_as(
        r#"
        SELECT
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '1 day'
            )::bigint,
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '7 days'
            )::bigint
        FROM app_usage_event
        WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let breakdown: Vec<(String, i64)> = sqlx::query_as(
        r#"
        SELECT event_type, COUNT(*)::bigint
        FROM app_usage_event
        WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '7 days'
        GROUP BY event_type
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let event_counts_last_7d: HashMap<String, i64> = breakdown.into_iter().collect();

    // Jobs created today (UTC midnight to now) — used for quota display.
    let jobs_today: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Effective quota for this user.
    let daily_job_quota = quota::effective_daily_job_quota_for_user(pool, uid)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let quota_remaining = daily_job_quota.map(|cap| (cap - jobs_today).max(0));

    Ok(Json(UsageSummaryResponse {
        events_last_24h: row.0,
        events_last_7d: row.1,
        event_counts_last_7d,
        jobs_today,
        daily_job_quota,
        quota_remaining,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn usage_summary_response_serialize_with_quota() {
        let mut event_counts = HashMap::new();
        event_counts.insert("generation_job.succeeded".to_string(), 5i64);
        event_counts.insert("generation_job.created".to_string(), 3i64);

        let resp = UsageSummaryResponse {
            events_last_24h: 5,
            events_last_7d: 10,
            event_counts_last_7d: event_counts,
            jobs_today: 3,
            daily_job_quota: Some(10),
            quota_remaining: Some(7),
        };

        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"events_last_24h\":5"));
        assert!(json.contains("\"events_last_7d\":10"));
        assert!(json.contains("\"jobs_today\":3"));
        assert!(json.contains("\"daily_job_quota\":10"));
        assert!(json.contains("\"quota_remaining\":7"));
    }

    #[test]
    fn usage_summary_response_serialize_without_quota() {
        let resp = UsageSummaryResponse {
            events_last_24h: 0,
            events_last_7d: 0,
            event_counts_last_7d: HashMap::new(),
            jobs_today: 0,
            daily_job_quota: None,
            quota_remaining: None,
        };

        let json = serde_json::to_string(&resp).unwrap();
        // quota_remaining should be skipped when None
        assert!(!json.contains("quota_remaining"));
    }

    #[test]
    fn usage_summary_response_with_zero_remaining() {
        let resp = UsageSummaryResponse {
            events_last_24h: 10,
            events_last_7d: 50,
            event_counts_last_7d: HashMap::new(),
            jobs_today: 10,
            daily_job_quota: Some(10),
            quota_remaining: Some(0),
        };

        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"quota_remaining\":0"));
    }
}
