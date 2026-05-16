//! 套餐层级配额执行（§12.0 / §12.3）。
//!
//! **免费层默认值**（可通过环境变量覆盖）：
//! - `QUOTA_FREE_DAILY_JOBS`：每个用户每个自然日最大生成任务数（默认 20）
//!
//! 每个用户的覆盖值可以存储在 `app_user_profile.daily_job_quota`（可为空；
//! NULL 表示"使用层级默认值"）。迁移会添加该列。
//!
//! 配额检查是**尽力而为**的：在高并发下存在小的竞争窗口（两个请求都在插入前通过计数检查）。
//! 这对于 MVP 是可接受的；更严格的方法会使用 PG 咨询锁或带 `FOR UPDATE` 的计数器表。

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::LazyLock;

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{billing_errors::quota_exceeded_billing_i18n, ApiError};

/// Quota denial metrics for observability (Task 3.4).
struct QuotaMetrics {
    /// Total quota denials (all scopes)
    total_denials: AtomicU64,
    /// User-scope quota denials
    user_scope_denials: AtomicU64,
    /// Workspace-scope quota denials
    workspace_scope_denials: AtomicU64,
}

impl QuotaMetrics {
    const fn new() -> Self {
        Self {
            total_denials: AtomicU64::new(0),
            user_scope_denials: AtomicU64::new(0),
            workspace_scope_denials: AtomicU64::new(0),
        }
    }

    fn record_denial(&self, scope: &crate::metering::BillingScope) {
        self.total_denials.fetch_add(1, Ordering::Relaxed);
        match scope {
            crate::metering::BillingScope::User => {
                self.user_scope_denials.fetch_add(1, Ordering::Relaxed);
            }
            crate::metering::BillingScope::Workspace => {
                self.workspace_scope_denials.fetch_add(1, Ordering::Relaxed);
            }
        }
    }
}

static QUOTA_METRICS: LazyLock<QuotaMetrics> = LazyLock::new(QuotaMetrics::new);

/// Get current quota denial metrics snapshot.
///
/// Returns (total_denials, user_scope_denials, workspace_scope_denials).
pub fn quota_metrics_snapshot() -> (u64, u64, u64) {
    (
        QUOTA_METRICS.total_denials.load(Ordering::Relaxed),
        QUOTA_METRICS.user_scope_denials.load(Ordering::Relaxed),
        QUOTA_METRICS
            .workspace_scope_denials
            .load(Ordering::Relaxed),
    )
}

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

/// Resolve the effective daily-job quota for a user (public for usage summary).
///
/// Priority:
/// 1. `app_user_profile.daily_job_quota` (per-user override, if non-NULL)
/// 2. Tier default from env / constant
///
/// Returns `None` if the user has an unlimited quota (e.g. `enterprise` tier with no cap).
pub async fn effective_daily_job_quota_and_tier_for_user(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<(Option<i64>, String), sqlx::Error> {
    let row: Option<(String, Option<i64>)> = sqlx::query_as(
        r#"
        SELECT plan_tier, daily_job_quota::bigint
        FROM app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    let (tier, per_user_override) = row.unwrap_or_else(|| ("free".to_string(), None));

    if let Some(cap) = per_user_override {
        return Ok((Some(cap), tier));
    }

    let cap = match tier.as_str() {
        "free" => Some(free_daily_jobs_limit()),
        "creator" => Some(free_daily_jobs_limit() * 40),
        "pro" => Some(free_daily_jobs_limit() * 125),
        "studio" => Some(free_daily_jobs_limit() * 400),
        "enterprise" => None,
        _ => Some(free_daily_jobs_limit()),
    };

    Ok((cap, tier))
}

pub async fn effective_daily_job_quota_for_user(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Option<i64>, sqlx::Error> {
    effective_daily_job_quota_and_tier_for_user(pool, user_id)
        .await
        .map(|(cap, _)| cap)
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

/// Count jobs created by `workspace_id` in the current natural UTC day (midnight-to-now).
///
/// Used for workspace-scope billing when `billing_scope = Workspace`.
async fn workspace_jobs_today(pool: &PgPool, workspace_id: Uuid) -> Result<i64, sqlx::Error> {
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE workspace_id = $1
          AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
        "#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await?;
    Ok(count)
}

/// Check whether `user_id` may create another generation job today.
///
/// Returns `Ok(())` if allowed, or `Err(ApiError::QuotaExceeded)` if the daily cap is reached.
///
/// **Legacy user-scope path**: This function is preserved for backward compatibility
/// and is used when `billing_scope = User`. New code should use
/// `check_daily_job_quota_with_context()` which respects workspace-scope billing.
pub async fn check_daily_job_quota(pool: &PgPool, user_id: Uuid) -> Result<(), ApiError> {
    let (cap, plan_tier) = effective_daily_job_quota_and_tier_for_user(pool, user_id)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(limit) = cap else {
        return Ok(());
    };

    let used = jobs_today(pool, user_id)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if used >= limit {
        return Err(quota_exceeded_billing_i18n(limit as u64, &plan_tier));
    }

    Ok(())
}

/// Check whether a user may create another generation job today, respecting billing scope.
///
/// This function uses the effective billing context to determine whether to enforce
/// user-scope or workspace-scope quota limits.
///
/// ## Arguments
///
/// - `pool`: Database connection pool
/// - `user_id`: User requesting the operation
/// - `workspace_id`: Current workspace context
/// - `config`: Global billing configuration
///
/// ## Returns
///
/// - `Ok(())`: User is allowed to create a job
/// - `Err(ApiError::QuotaExceeded)`: Daily quota limit reached
/// - `Err(ApiError)`: Database error or missing data
///
/// ## Observability
///
/// On quota denial, logs structured data with `billing_scope`, `user_id`, and `workspace_id`
/// for ops debugging (Requirement 4.4).
pub async fn check_daily_job_quota_with_context(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
    config: &crate::metering::BillingConfig,
) -> Result<(), ApiError> {
    use crate::metering::{get_effective_billing_context, BillingScope};

    // Get effective billing context
    let context = get_effective_billing_context(pool, user_id, workspace_id, config).await?;

    // Determine limit based on billing scope
    let limit = match context.daily_job_quota {
        Some(cap) => cap,
        None => {
            // Unlimited tier
            return Ok(());
        }
    };

    // Count jobs based on billing scope
    let used = match context.billing_scope {
        BillingScope::User => jobs_today(pool, user_id).await,
        BillingScope::Workspace => workspace_jobs_today(pool, workspace_id).await,
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if used >= limit {
        // Record metric for ops monitoring (Task 3.4)
        QUOTA_METRICS.record_denial(&context.billing_scope);

        // Log quota denial with billing context (Requirement 4.4 / Task 3.4)
        tracing::warn!(
            user_id = %user_id,
            workspace_id = %workspace_id,
            billing_scope = ?context.billing_scope,
            plan_tier = %context.plan_tier,
            limit = limit,
            used = used,
            "Daily job quota exceeded"
        );

        return Err(quota_exceeded_billing_i18n(
            limit as u64,
            &context.plan_tier,
        ));
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
        const { assert!(DEFAULT_FREE_DAILY_JOBS > 0) };
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

    #[test]
    fn quota_metrics_snapshot_returns_counters() {
        // Get initial snapshot
        let (total_before, user_before, workspace_before) = quota_metrics_snapshot();

        // Simulate a user-scope denial
        QUOTA_METRICS.record_denial(&crate::metering::BillingScope::User);

        // Get updated snapshot
        let (total_after, user_after, workspace_after) = quota_metrics_snapshot();

        // Verify counters incremented correctly
        assert_eq!(total_after, total_before + 1);
        assert_eq!(user_after, user_before + 1);
        assert_eq!(workspace_after, workspace_before); // unchanged

        // Simulate a workspace-scope denial
        QUOTA_METRICS.record_denial(&crate::metering::BillingScope::Workspace);

        // Get final snapshot
        let (total_final, user_final, workspace_final) = quota_metrics_snapshot();

        // Verify counters incremented correctly
        assert_eq!(total_final, total_after + 1);
        assert_eq!(user_final, user_after); // unchanged
        assert_eq!(workspace_final, workspace_after + 1);
    }
}
