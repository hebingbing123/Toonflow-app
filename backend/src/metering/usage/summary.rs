//! `GET /api/v1/usage/summary`：用量与配额提示。

use std::collections::HashMap;

use axum::extract::State;
use axum::http::HeaderMap;
use axum::Json;
use serde::Serialize;
use utoipa::ToSchema;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::quota;
use crate::state::AppState;

#[derive(Serialize, ToSchema)]
pub(crate) struct UsageSummaryResponse {
    pub(crate) events_last_24h: i64,
    pub(crate) events_last_7d: i64,
    /// Per-`event_type` counts in the rolling last 7 days (same window as `events_last_7d`).
    pub(crate) event_counts_last_7d: HashMap<String, i64>,
    /// Jobs created today (UTC natural day) — same counter used by quota enforcement.
    pub(crate) jobs_today: i64,
    /// Effective daily job cap for this user (`null` = unlimited).
    pub(crate) daily_job_quota: Option<i64>,
    /// Remaining jobs allowed today (`null` = unlimited). `0` means quota is exhausted.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) quota_remaining: Option<i64>,
}

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
pub(super) async fn usage_summary(
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
