//! `GET /api/v1/me` — JWT sub + `app_user_profile` 等。

use axum::extract::State;
use axum::http::HeaderMap;
use axum::Json;
use chrono::{DateTime, Utc};
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_claims;
use crate::error::ApiError;
use crate::state::{AppState, MemoryConfig};

use super::types::MeResponse;

#[derive(FromRow)]
struct UserProfileRow {
    plan_tier: String,
    billing_currency: Option<String>,
    billing_provider: Option<String>,
    subscription_status: Option<String>,
    subscription_current_period_end_at: Option<DateTime<Utc>>,
    daily_job_quota: Option<i64>,
    memory_config: Option<sqlx::types::Json<MemoryConfig>>,
}

#[utoipa::path(
    get,
    path = "/api/v1/me",
    operation_id = "meV1",
    tag = "session",
    summary = "Current user from JWT plus SaaS profile when database is configured",
    description = "Always returns JWT `sub` (and `email` when present in claims). When **`DATABASE_URL`** is set, loads **`plan_tier`** / billing fields from **`app_user_profile`** (defaults to **`plan_tier: free`** when no row).\nIncludes `subscription_status` and `subscription_current_period_end_at` when present in profile.\nAlso returns **`daily_job_quota`** (effective cap; `null` = unlimited) and **`jobs_today`** (UTC-day count) when the database is connected — clients can use these to render quota progress without a separate call.",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "OK", body = MeResponse),
        (status = 401, description = "Missing or invalid Bearer token", body = crate::error::ErrorBody),
        (status = 503, description = "`SUPABASE_JWT_SECRET` not configured, or database error when loading profile", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn me(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MeResponse>, ApiError> {
    let claims = require_claims(&state, &headers)?;
    let sub = Uuid::parse_str(claims.sub.trim()).map_err(|_| ApiError::BadToken)?;

    let (
        plan_tier,
        billing_currency,
        billing_provider,
        subscription_status,
        subscription_current_period_end_at,
        per_user_quota,
        jobs_today,
        memory_cfg,
    ) = if let Some(pool) = state.pool.as_ref() {
        let row = sqlx::query_as::<_, UserProfileRow>(
            r#"
            SELECT
              plan_tier,
              billing_currency,
              billing_provider,
              subscription_status,
              subscription_current_period_end_at,
              daily_job_quota,
              memory_config
            FROM app_user_profile
            WHERE user_id = $1
            "#,
        )
        .bind(sub)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let (
            tier,
            currency,
            provider,
            subscription_status,
            subscription_current_period_end_at,
            per_user_quota,
            mem_cfg,
        ) = match row {
            Some(r) => (
                r.plan_tier,
                r.billing_currency,
                r.billing_provider,
                r.subscription_status,
                r.subscription_current_period_end_at,
                r.daily_job_quota,
                r.memory_config.map(|j| j.0),
            ),
            None => ("free".to_string(), None, None, None, None, None, None),
        };

        let today: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE owner_user_id = $1
              AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
            "#,
        )
        .bind(sub)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        (
            tier,
            currency,
            provider,
            subscription_status,
            subscription_current_period_end_at,
            per_user_quota,
            Some(today),
            mem_cfg,
        )
    } else {
        ("free".to_string(), None, None, None, None, None, None, None)
    };

    // Resolve effective quota using same logic as quota::effective_daily_job_quota
    // but inline (avoids a second DB round-trip).
    let daily_job_quota = if per_user_quota.is_some() {
        per_user_quota
    } else {
        let free_limit = std::env::var("QUOTA_FREE_DAILY_JOBS")
            .ok()
            .and_then(|s| s.trim().parse::<i64>().ok())
            .filter(|&n| n > 0)
            .unwrap_or(20);
        match plan_tier.as_str() {
            "enterprise" => None,
            "free" => Some(free_limit),
            "creator" => Some(free_limit * 40),
            "pro" => Some(free_limit * 125),
            "studio" => Some(free_limit * 400),
            _ => Some(free_limit),
        }
    };

    // Resolve memory_config (use DB value or fall back to server defaults).
    let memory_config = if memory_cfg.is_some() {
        memory_cfg
    } else if state.pool.is_none() {
        Some(state.memory_config.read().await.clone())
    } else {
        None // DB connected but user has no custom config; don't leak server defaults.
    };

    Ok(Json(MeResponse {
        sub,
        email: claims.email,
        plan_tier,
        billing_currency,
        billing_provider,
        subscription_status,
        subscription_current_period_end_at,
        daily_job_quota,
        jobs_today,
        memory_config,
    }))
}
