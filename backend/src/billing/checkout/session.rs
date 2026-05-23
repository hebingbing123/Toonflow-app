//! Checkout session persistence.

use chrono::{DateTime, Duration, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, Clone, sqlx::FromRow)]
#[allow(dead_code)]
pub struct CheckoutSessionRow {
    pub id: Uuid,
    pub user_id: Uuid,
    pub plan_tier: String,
    pub provider: String,
    pub currency: String,
    pub amount_cents: i64,
    pub status: String,
    pub provider_trade_no: Option<String>,
    pub provider_session_id: Option<String>,
    pub pay_url: Option<String>,
    pub period_days: i32,
    pub expires_at: DateTime<Utc>,
    pub paid_at: Option<DateTime<Utc>>,
}

pub struct NewCheckoutSession<'a> {
    pub user_id: Uuid,
    pub plan_tier: &'a str,
    pub provider: &'a str,
    pub currency: &'a str,
    pub amount_cents: i64,
    pub period_days: i32,
    pub provider_trade_no: &'a str,
    pub pay_url: Option<&'a str>,
    pub provider_session_id: Option<&'a str>,
    pub ttl_hours: i64,
}

pub async fn insert_session(
    pool: &PgPool,
    session: NewCheckoutSession<'_>,
) -> Result<CheckoutSessionRow, ApiError> {
    let expires_at = Utc::now() + Duration::hours(session.ttl_hours);
    sqlx::query_as::<_, CheckoutSessionRow>(
        r#"
        INSERT INTO app_billing_checkout_session (
          user_id, plan_tier, provider, currency, amount_cents, status,
          provider_trade_no, pay_url, provider_session_id, period_days, expires_at
        )
        VALUES ($1, $2, $3, $4, $5, 'pending', $6, $7, $8, $9, $10)
        RETURNING
          id, user_id, plan_tier, provider, currency, amount_cents, status,
          provider_trade_no, provider_session_id, pay_url, period_days,
          expires_at, paid_at
        "#,
    )
    .bind(session.user_id)
    .bind(session.plan_tier)
    .bind(session.provider)
    .bind(session.currency)
    .bind(session.amount_cents)
    .bind(session.provider_trade_no)
    .bind(session.pay_url)
    .bind(session.provider_session_id)
    .bind(session.period_days)
    .bind(expires_at)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub async fn get_session_for_user(
    pool: &PgPool,
    session_id: Uuid,
    user_id: Uuid,
) -> Result<Option<CheckoutSessionRow>, ApiError> {
    sqlx::query_as::<_, CheckoutSessionRow>(
        r#"
        SELECT
          id, user_id, plan_tier, provider, currency, amount_cents, status,
          provider_trade_no, provider_session_id, pay_url, period_days,
          expires_at, paid_at
        FROM app_billing_checkout_session
        WHERE id = $1 AND user_id = $2
        "#,
    )
    .bind(session_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub async fn find_by_provider_trade_no(
    pool: &PgPool,
    provider: &str,
    provider_trade_no: &str,
) -> Result<Option<CheckoutSessionRow>, ApiError> {
    sqlx::query_as::<_, CheckoutSessionRow>(
        r#"
        SELECT
          id, user_id, plan_tier, provider, currency, amount_cents, status,
          provider_trade_no, provider_session_id, pay_url, period_days,
          expires_at, paid_at
        FROM app_billing_checkout_session
        WHERE provider = $1 AND provider_trade_no = $2
        "#,
    )
    .bind(provider)
    .bind(provider_trade_no)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub async fn find_by_id(
    pool: &PgPool,
    session_id: Uuid,
) -> Result<Option<CheckoutSessionRow>, ApiError> {
    sqlx::query_as::<_, CheckoutSessionRow>(
        r#"
        SELECT
          id, user_id, plan_tier, provider, currency, amount_cents, status,
          provider_trade_no, provider_session_id, pay_url, period_days,
          expires_at, paid_at
        FROM app_billing_checkout_session
        WHERE id = $1
        "#,
    )
    .bind(session_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub async fn mark_paid(pool: &PgPool, session_id: Uuid) -> Result<bool, ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_billing_checkout_session
        SET status = 'paid', paid_at = NOW(), updated_at = NOW()
        WHERE id = $1 AND status = 'pending'
        "#,
    )
    .bind(session_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(updated.rows_affected() > 0)
}

#[allow(dead_code)]
pub async fn expire_stale_pending(pool: &PgPool) -> Result<u64, ApiError> {
    let res = sqlx::query(
        r#"
        UPDATE app_billing_checkout_session
        SET status = 'expired', updated_at = NOW()
        WHERE status = 'pending' AND expires_at < NOW()
        "#,
    )
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected())
}

pub async fn set_provider_session_id(
    pool: &PgPool,
    session_id: Uuid,
    provider_session_id: &str,
    pay_url: Option<&str>,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_billing_checkout_session
        SET provider_session_id = $2,
            pay_url = COALESCE($3, pay_url),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(session_id)
    .bind(provider_session_id)
    .bind(pay_url)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub async fn set_billing_customer_id(
    pool: &PgPool,
    user_id: Uuid,
    provider: &str,
    customer_id: &str,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_user_profile
        SET billing_customer_id = $2,
            billing_provider = $3,
            updated_at = NOW()
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .bind(customer_id)
    .bind(provider)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
