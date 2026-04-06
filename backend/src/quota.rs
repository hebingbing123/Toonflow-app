//! Plan-tier quota enforcement (§12.0 / §12.3).
//!
//! **Free tier defaults** (overridable via env):
//! - `QUOTA_FREE_DAILY_JOBS`: max generation jobs per natural day per user (default 20)
//!
//! Per-user overrides can be stored in `app_user_profile.daily_job_quota` (nullable;
//! NULL means "use tier default"). The migration adds that column.
//!
//! Quota check is **best-effort**: a small race window exists under high concurrency
//! (two requests both pass the count check before either inserts). This is acceptable
//! for MVP; a stricter approach would use a PG advisory lock or a counter table with
//! `FOR UPDATE`.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// Default daily job quota for the `free` plan tier.
const DEFAULT_FREE_DAILY_JOBS: i64 = 20;

/// Read `QUOTA_FREE_DAILY_JOBS` from env, falling back to [`DEFAULT_FREE_DAILY_JOBS`].
fn free_daily_jobs_limit() -> i64 {
    std::env::var("QUOTA_FREE_DAILY_JOBS")
        .ok()
        .and_then(|s| s.trim().parse::<i64>().ok())
        .filter(|&n| n > 0)
        .unwrap_or(DEFAULT_FREE_DAILY_JOBS)
}

/// Resolve the effective daily-job quota for a user.
///
/// Priority:
/// 1. `app_user_profile.daily_job_quota` (per-user override, if column exists and non-NULL)
/// 2. Tier default from env / constant
///
/// Returns `None` if the user has an unlimited quota (e.g. `enterprise` tier with no cap).
async fn effective_daily_job_quota(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Option<i64>, sqlx::Error> {
    // Fetch plan_tier and optional per-user override in one query.
    // `daily_job_quota` column is added by migration 20260417120000_app_user_profile_quota.sql.
    let row: Option<(String, Option<i64>)> = sqlx::query_as(
        r#"
        SELECT plan_tier, daily_job_quota
        FROM app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    let (tier, per_user_override) = row.unwrap_or_else(|| ("free".to_string(), None));

    // Per-user override wins regardless of tier.
    if let Some(cap) = per_user_override {
        return Ok(Some(cap));
    }

    // Tier-based defaults.
    let cap = match tier.as_str() {
        "free" => Some(free_daily_jobs_limit()),
        "creator" => Some(free_daily_jobs_limit() * 40), // ~800/day
        "pro" => Some(free_daily_jobs_limit() * 125),    // ~2500/day
        "studio" => Some(free_daily_jobs_limit() * 400), // ~8000/day
        "enterprise" => None,                            // unlimited
        _ => Some(free_daily_jobs_limit()),              // unknown tier → free default
    };

    Ok(cap)
}

/// Count jobs created by `user_id` in the current natural UTC day (midnight-to-now).
async fn jobs_today(pool: &PgPool, user_id: Uuid) -> Result<i64, sqlx::Error> {
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await?;
    Ok(count)
}

/// Check whether `user_id` may create another generation job today.
///
/// Returns `Ok(())` if allowed, or `Err(ApiError::QuotaExceeded)` if the daily cap is reached.
pub async fn check_daily_job_quota(pool: &PgPool, user_id: Uuid) -> Result<(), ApiError> {
    let cap = effective_daily_job_quota(pool, user_id)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(limit) = cap else {
        // Unlimited tier.
        return Ok(());
    };

    let used = jobs_today(pool, user_id)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if used >= limit {
        return Err(ApiError::QuotaExceeded(format!(
            "Daily generation job limit of {limit} reached for your plan. Resets at midnight UTC."
        )));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Parse helper extracted from `free_daily_jobs_limit` logic — testable without env mutation.
    fn parse_daily_jobs_limit(raw: Option<&str>) -> i64 {
        raw.and_then(|s| s.trim().parse::<i64>().ok())
            .filter(|&n| n > 0)
            .unwrap_or(DEFAULT_FREE_DAILY_JOBS)
    }

    #[test]
    fn default_is_positive() {
        assert!(DEFAULT_FREE_DAILY_JOBS > 0);
    }

    #[test]
    fn parse_accepts_positive_value() {
        assert_eq!(parse_daily_jobs_limit(Some("5")), 5);
    }

    #[test]
    fn parse_rejects_zero_falls_back_to_default() {
        assert_eq!(parse_daily_jobs_limit(Some("0")), DEFAULT_FREE_DAILY_JOBS);
    }

    #[test]
    fn parse_rejects_negative_falls_back_to_default() {
        assert_eq!(parse_daily_jobs_limit(Some("-1")), DEFAULT_FREE_DAILY_JOBS);
    }

    #[test]
    fn parse_none_falls_back_to_default() {
        assert_eq!(parse_daily_jobs_limit(None), DEFAULT_FREE_DAILY_JOBS);
    }

    #[test]
    fn free_daily_jobs_limit_returns_positive() {
        // The live function reads env; just assert it returns something positive.
        assert!(free_daily_jobs_limit() > 0);
    }
}
