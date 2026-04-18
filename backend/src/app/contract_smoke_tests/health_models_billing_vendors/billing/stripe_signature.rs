use super::super::super::helpers::*;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::Method;
use axum::http::Request;
use axum::http::StatusCode;

/// Stripe-Signature scheme: valid HMAC within tolerance → missing pool → **`database_error`** (not 401).
#[tokio::test]
async fn billing_webhook_stripe_signature_database_error_when_hmac_ok_but_pool_missing() {
    let _lock = billing_webhook_test_lock().await;
    const SM_SECRET: &str = "whsec_contract-smoke-stripe-secret!!";
    let prev = super::set_billing_webhook_secret(SM_SECRET);

    let body_json = r#"{"id":"evt_stripe_smoke_no_db"}"#;
    let body = body_json.as_bytes();
    let ts: u64 = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(1_700_000_000);
    let stripe_hdr = super::stripe_signature_header(SM_SECRET, ts, body);

    let (status, v) = oneshot_json_state(
        smoke_state(),
        Request::builder()
            .method(Method::POST)
            .uri("/api/v1/webhooks/billing")
            .header(header::CONTENT_TYPE, "application/json")
            .header("stripe-signature", stripe_hdr)
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(body_json.to_string()))
            .unwrap(),
    )
    .await;

    super::restore_env_var("BILLING_WEBHOOK_SECRET", prev);

    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

/// Stripe-Signature with expired timestamp → **401 invalid_webhook_signature**.
#[tokio::test]
async fn billing_webhook_stripe_signature_rejects_expired_timestamp() {
    let _lock = billing_webhook_test_lock().await;
    const SM_SECRET: &str = "whsec_contract-smoke-stripe-secret!!";
    let prev = super::set_billing_webhook_secret(SM_SECRET);

    let body_json = r#"{"id":"evt_stripe_smoke_expired"}"#;
    let body = body_json.as_bytes();
    let ts: u64 = 1;
    let stripe_hdr = super::stripe_signature_header(SM_SECRET, ts, body);

    let (status, v) = oneshot_json_state(
        smoke_state(),
        Request::builder()
            .method(Method::POST)
            .uri("/api/v1/webhooks/billing")
            .header(header::CONTENT_TYPE, "application/json")
            .header("stripe-signature", stripe_hdr)
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(body_json.to_string()))
            .unwrap(),
    )
    .await;

    super::restore_env_var("BILLING_WEBHOOK_SECRET", prev);

    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "invalid_webhook_signature");
}
