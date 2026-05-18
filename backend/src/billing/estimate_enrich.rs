//! Enrich billing estimate with BYOK detection and quota context.

use sqlx::PgPool;
use uuid::Uuid;

use crate::metering::quota;
use crate::vendor::catalog::pricing::{vendor_id_from_model_id, BillingEstimateResponse};

pub(crate) async fn enrich_estimate_response(
    pool: &PgPool,
    user_id: Uuid,
    response: &mut BillingEstimateResponse,
) -> Result<(), sqlx::Error> {
    if let Some(vendor_id) = vendor_id_from_model_id(&response.model_id) {
        let has_cred: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM app_vendor_credential
                WHERE owner_user_id = $1 AND vendor_id = $2
                  AND (
                    api_key_encrypted IS NOT NULL
                    OR api_secret_encrypted IS NOT NULL
                    OR api_token_encrypted IS NOT NULL
                  )
            )
            "#,
        )
        .bind(user_id)
        .bind(&vendor_id)
        .fetch_one(pool)
        .await?;
        if has_cred {
            response.platform_billing_exempt = true;
            response
                .warnings
                .push("platform_billing_exempt".to_string());
        }
    }

    let (daily_cap, _tier) =
        quota::effective_daily_job_quota_and_tier_for_user(pool, user_id).await?;
    let today: i64 = sqlx::query_scalar(
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

    response.jobs_today = Some(today);
    response.daily_job_quota = daily_cap;

    if let Some(cap) = daily_cap {
        if cap > 0 {
            let remaining = (cap - today).max(0);
            response.quota_remaining = Some(remaining);
            let after = today + i64::from(response.quota_impact_jobs);
            let pct = (after as f64 / cap as f64 * 100.0).clamp(0.0, 100.0);
            response.quota_usage_percent_after = Some(pct);
        }
    }

    Ok(())
}
