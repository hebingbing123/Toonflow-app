use super::super::super::helpers::*;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::HeaderValue;
use axum::http::Method;
use axum::http::Request;
use axum::http::StatusCode;
use hmac::{Hmac, Mac};
use sha2::Sha256;

/// **`POST /api/v1/webhooks/billing`** uses HMAC, not Bearer. Without **`BILLING_WEBHOOK_SECRET`** → **503** `webhook_not_configured`; with secret set but no/invalid **`X-Toonflow-Signature`** → **401** `invalid_webhook_signature` (before Postgres).
#[tokio::test]
async fn billing_webhook_smoke_rejects_without_valid_hmac() {
    let _lock = billing_webhook_test_lock().await;
    let (status, v) = post_json("/api/v1/webhooks/billing", "{}").await;
    let secret_set = std::env::var("BILLING_WEBHOOK_SECRET")
        .map(|s| !s.trim().is_empty())
        .unwrap_or(false);
    if secret_set {
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(v["code"], "invalid_webhook_signature");
    } else {
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "webhook_not_configured");
    }
}

/// After HMAC verification, missing Postgres must surface **`database_error`** (not **200**).
#[tokio::test]
async fn billing_webhook_database_error_when_hmac_ok_but_pool_missing() {
    let _lock = billing_webhook_test_lock().await;
    let prev = std::env::var_os("BILLING_WEBHOOK_SECRET");
    const SM_SECRET: &str = "contract-smoke-billing-hmac-secret-bytes!!";
    std::env::set_var("BILLING_WEBHOOK_SECRET", SM_SECRET);

    let body_json = r#"{"id":"evt_contract_smoke_billing_no_db"}"#;
    let body = body_json.as_bytes();
    let ts: u64 = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(1_700_000_000);
    let ts_str = ts.to_string();
    let mut mac = Hmac::<Sha256>::new_from_slice(SM_SECRET.as_bytes()).expect("hmac key");
    mac.update(ts_str.as_bytes());
    mac.update(b".");
    mac.update(body);
    let sig = hex::encode(mac.finalize().into_bytes());
    let sig_hdr = HeaderValue::from_str(&format!("sha256={sig}")).expect("signature header");

    let (status, v) = oneshot_json_state(
        smoke_state(),
        Request::builder()
            .method(Method::POST)
            .uri("/api/v1/webhooks/billing")
            .header(header::CONTENT_TYPE, "application/json")
            .header("x-toonflow-signature", sig_hdr)
            .header("x-toonflow-timestamp", ts_str)
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(body_json.to_string()))
            .unwrap(),
    )
    .await;

    match &prev {
        Some(p) => std::env::set_var("BILLING_WEBHOOK_SECRET", p),
        None => std::env::remove_var("BILLING_WEBHOOK_SECRET"),
    }

    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
