//! Checkout completion ordering: plan ingest before mark_paid, and paid-session retry.

use super::super::*;
use chrono::{Duration, Utc};
use uuid::Uuid;

const CHECKOUT_ORDER_USER: &str = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";

async fn ensure_checkout_order_user(pool: &PgPool, user_id: Uuid) {
    sqlx::query(
        r#"
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
        VALUES ($1, 'billing-checkout-order@example.com', 'contract-test-password', NOW(), NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
        "#,
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("auth user");
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, plan_tier, daily_job_quota)
        VALUES ($1, 'free', 20)
        ON CONFLICT (user_id) DO UPDATE SET plan_tier = 'free', daily_job_quota = 20
        "#,
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("profile");
}

async fn cleanup_checkout_order_fixtures(pool: &PgPool, user_id: Uuid) {
    let _ = sqlx::query("DELETE FROM app_billing_checkout_session WHERE user_id = $1")
        .bind(user_id)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM app_billing_webhook_event WHERE payload->>'user_id' = $1")
        .bind(user_id.to_string())
        .execute(pool)
        .await;
    let _ = sqlx::query(
        r#"
        UPDATE app_user_profile
        SET plan_tier = 'free', updated_at = NOW()
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .execute(pool)
    .await;
}

async fn insert_checkout_session(pool: &PgPool, user_id: Uuid, session_id: Uuid, status: &str) {
    let trade_no = format!("pg-checkout-order-{session_id}");
    sqlx::query(
        r#"
        INSERT INTO app_billing_checkout_session (
          id, user_id, plan_tier, provider, currency, amount_cents, status,
          provider_trade_no, period_days, expires_at, paid_at
        )
        VALUES ($1, $2, 'creator', 'alipay', 'CNY', 9900, $3, $4, 30, NOW() + INTERVAL '1 hour',
                CASE WHEN $3 = 'paid' THEN NOW() ELSE NULL END)
        "#,
    )
    .bind(session_id)
    .bind(user_id)
    .bind(status)
    .bind(trade_no)
    .execute(pool)
    .await
    .expect("insert checkout session");
}

async fn profile_plan_tier(pool: &PgPool, user_id: Uuid) -> String {
    sqlx::query_as::<_, (String,)>(r#"SELECT plan_tier FROM app_user_profile WHERE user_id = $1"#)
        .bind(user_id)
        .fetch_one(pool)
        .await
        .expect("profile tier")
        .0
}

async fn session_status(pool: &PgPool, session_id: Uuid) -> String {
    sqlx::query_as::<_, (String,)>(
        r#"SELECT status FROM app_billing_checkout_session WHERE id = $1"#,
    )
    .bind(session_id)
    .fetch_one(pool)
    .await
    .expect("session status")
    .0
}

#[tokio::test]
#[ignore = "needs DATABASE_URL; cargo test billing_checkout_completion_order -- --ignored"]
async fn checkout_complete_upgrades_plan_and_marks_paid() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect");

    let user_id = Uuid::parse_str(CHECKOUT_ORDER_USER).unwrap();
    ensure_checkout_order_user(&pool, user_id).await;
    cleanup_checkout_order_fixtures(&pool, user_id).await;

    let session_id = Uuid::new_v4();
    insert_checkout_session(&pool, user_id, session_id, "pending").await;

    let session = crate::billing::find_checkout_session(&pool, session_id)
        .await
        .expect("load session")
        .expect("session row");
    assert_eq!(session.status, "pending");
    assert_eq!(profile_plan_tier(&pool, user_id).await, "free");

    let event_id = format!("pg-checkout-order-{session_id}");
    crate::billing::complete_checkout_session(
        &pool,
        &session,
        &event_id,
        serde_json::json!({ "trade_status": "TRADE_SUCCESS" }),
    )
    .await
    .expect("complete checkout");

    assert_eq!(profile_plan_tier(&pool, user_id).await, "creator");
    assert_eq!(session_status(&pool, session_id).await, "paid");

    cleanup_checkout_order_fixtures(&pool, user_id).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL; cargo test billing_checkout_paid_session_reconciles_plan -- --ignored"]
async fn checkout_paid_session_reconciles_plan_when_profile_still_free() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect");

    let user_id = Uuid::parse_str(CHECKOUT_ORDER_USER).unwrap();
    ensure_checkout_order_user(&pool, user_id).await;
    cleanup_checkout_order_fixtures(&pool, user_id).await;

    let session_id = Uuid::new_v4();
    insert_checkout_session(&pool, user_id, session_id, "paid").await;
    assert_eq!(profile_plan_tier(&pool, user_id).await, "free");

    let session = crate::billing::find_checkout_session(&pool, session_id)
        .await
        .expect("load session")
        .expect("session row");
    assert_eq!(session.status, "paid");

    let event_id = format!("pg-checkout-order-retry-{session_id}");
    crate::billing::complete_checkout_session(
        &pool,
        &session,
        &event_id,
        serde_json::json!({ "trade_status": "TRADE_SUCCESS" }),
    )
    .await
    .expect("reconcile checkout");

    assert_eq!(profile_plan_tier(&pool, user_id).await, "creator");
    assert_eq!(session_status(&pool, session_id).await, "paid");

    cleanup_checkout_order_fixtures(&pool, user_id).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL; cargo test billing_checkout_pending_profile_upgraded_before_paid -- --ignored"]
async fn checkout_pending_session_upgrades_profile_before_mark_paid() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect");

    let user_id = Uuid::parse_str(CHECKOUT_ORDER_USER).unwrap();
    ensure_checkout_order_user(&pool, user_id).await;
    cleanup_checkout_order_fixtures(&pool, user_id).await;

    let session_id = Uuid::new_v4();
    insert_checkout_session(&pool, user_id, session_id, "pending").await;

    let session = crate::billing::find_checkout_session(&pool, session_id)
        .await
        .expect("load session")
        .expect("session row");

    let event_id = format!("pg-checkout-order-ordering-{session_id}");
    let period_end = Utc::now() + Duration::days(session.period_days as i64);
    let payload = serde_json::json!({
        "id": event_id,
        "provider": session.provider,
        "user_id": session.user_id.to_string(),
        "plan_tier": session.plan_tier,
        "subscription_status": "active",
        "subscription_current_period_end_at": period_end.to_rfc3339(),
        "subscription_status_updated_at": Utc::now().to_rfc3339(),
        "checkout_session_id": session.id.to_string(),
        "currency": session.currency,
        "amount_cents": session.amount_cents,
    });

    crate::billing::ingest_webhook(&pool, &payload)
        .await
        .expect("ingest webhook");
    assert_eq!(profile_plan_tier(&pool, user_id).await, "creator");
    assert_eq!(session_status(&pool, session_id).await, "pending");

    crate::billing::mark_checkout_paid(&pool, session_id)
        .await
        .expect("mark paid");
    assert_eq!(session_status(&pool, session_id).await, "paid");

    cleanup_checkout_order_fixtures(&pool, user_id).await;
}
