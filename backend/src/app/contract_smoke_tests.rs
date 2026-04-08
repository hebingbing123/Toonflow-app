use std::net::SocketAddr;
use std::sync::Arc;
use std::sync::OnceLock;

use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::{Method, Request, StatusCode};
use serde_json::Value;
use tokio::sync::RwLock;
use tower::ServiceExt;
use uuid::Uuid;

use super::build_router;
use super::jwt_fixture;
use super::vendor_credential_test_lock;
use crate::notify_hub::WsNotifyHub;
use crate::settings_about::settings_about_env_test_lock;
use crate::state::{AppState, MemoryConfig};
use axum::http::HeaderValue;
use hmac::{Hmac, Mac};
use sha2::Sha256;

/// Large enough for **`GET /api/v1/visual-manual`** (many bundled Markdown files).
const MAX_JSON: usize = 2 * 1024 * 1024;
/// Response bodies for **`GET /api/v1/skills/binary`** smoke (single reference image).
const MAX_PROBE_BYTES: usize = 512 * 1024;
/// Shared with [`jwt_fixture::encode_supabase_style`]; must satisfy Supabase-style `aud` + HS256 verify.
const TEST_JWT_SECRET: &[u8] = b"contract-smoke-jwt-secret-bytes-32chars!";
const NIL_JOB_UUID: &str = "00000000-0000-0000-0000-000000000000";

/// Serialize billing webhook tests that read or write **`BILLING_WEBHOOK_SECRET`** (avoids parallel **`cargo test`** flakes).
static BILLING_WEBHOOK_TEST_MUTEX: OnceLock<tokio::sync::Mutex<()>> = OnceLock::new();
async fn billing_webhook_test_lock() -> tokio::sync::MutexGuard<'static, ()> {
    BILLING_WEBHOOK_TEST_MUTEX
        .get_or_init(|| tokio::sync::Mutex::new(()))
        .lock()
        .await
}

fn test_addr() -> SocketAddr {
    SocketAddr::from(([127, 0, 0, 1], 42_042))
}

fn smoke_state() -> AppState {
    AppState {
        pool: None,
        jwt_secret: Some(TEST_JWT_SECRET.to_vec()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
    }
}

/// Same as [`smoke_state`] but JWT verification is disabled (production analogue: **`SUPABASE_JWT_SECRET` unset**).
fn smoke_state_without_jwt_secret() -> AppState {
    AppState {
        pool: None,
        jwt_secret: None,
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
    }
}

fn test_jwt(sub: Uuid) -> String {
    jwt_fixture::encode_supabase_style(sub, TEST_JWT_SECRET)
}

async fn oneshot_json_state(state: AppState, req: Request<Body>) -> (StatusCode, Value) {
    let app = build_router(state);
    let res = app.oneshot(req).await.unwrap();
    let status = res.status();
    let body = axum::body::to_bytes(res.into_body(), MAX_JSON)
        .await
        .unwrap();
    let v: Value = serde_json::from_slice(&body).expect("response body is json");
    (status, v)
}

async fn oneshot_json(req: Request<Body>) -> (StatusCode, Value) {
    oneshot_json_state(smoke_state(), req).await
}

async fn get_json(uri: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .uri(uri)
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn get_json_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn get_bytes_bearer(uri: &str, token: &str) -> (StatusCode, Vec<u8>, Option<String>) {
    let app = build_router(smoke_state());
    let res = app
        .oneshot(
            Request::builder()
                .uri(uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    let ct = res
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let body = axum::body::to_bytes(res.into_body(), MAX_PROBE_BYTES)
        .await
        .unwrap();
    (status, body.to_vec(), ct)
}

async fn post_json_bearer(uri: &str, token: &str, json_body: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

async fn post_json(uri: &str, json_body: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(uri)
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

async fn put_json(uri: &str, json_body: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::PUT)
            .uri(uri)
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

async fn patch_json_no_bearer(uri: &str, json_body: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::PATCH)
            .uri(uri)
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

async fn post_empty_no_bearer(uri: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(uri)
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn post_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn put_empty_no_bearer(uri: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::PUT)
            .uri(uri)
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn delete_empty_no_bearer(uri: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::DELETE)
            .uri(uri)
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn patch_json_bearer(uri: &str, token: &str, json_body: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::PATCH)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

async fn put_json_bearer(uri: &str, token: &str, json_body: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::PUT)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

async fn put_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::PUT)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn delete_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::DELETE)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

/// DELETE responses may be **204** with an empty body (e.g. **`/api/v1/skills/content`**).
async fn delete_json_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
    let app = build_router(smoke_state());
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    let body = axum::body::to_bytes(res.into_body(), MAX_JSON)
        .await
        .unwrap();
    let v = if body.is_empty() {
        Value::Null
    } else {
        serde_json::from_slice(&body).expect("non-empty delete response must be json")
    };
    (status, v)
}

async fn delete_json_no_bearer(uri: &str) -> (StatusCode, Value) {
    let app = build_router(smoke_state());
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(uri)
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    let body = axum::body::to_bytes(res.into_body(), MAX_JSON)
        .await
        .unwrap();
    let v = if body.is_empty() {
        Value::Null
    } else {
        serde_json::from_slice(&body).expect("non-empty delete response must be json")
    };
    (status, v)
}

#[tokio::test]
async fn health_routes_ok_without_database() {
    for uri in ["/health", "/api/v1/health"] {
        let (status, v) = get_json(uri).await;
        assert_eq!(status, StatusCode::OK, "uri={uri}");
        assert_eq!(v["status"], "ok");
        assert_eq!(v["service"], "toonflow-server");
    }
}

#[tokio::test]
async fn ping_ok_without_database() {
    let (status, v) = get_json("/api/v1/ping").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["ok"], true);
}

#[tokio::test]
async fn version_shape_matches_contract() {
    let (status, v) = get_json("/api/v1/version").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["service"], "toonflow-server");
    assert!(v["version"].as_str().is_some_and(|s| !s.is_empty()));
}

#[tokio::test]
async fn ready_without_database_reports_not_configured() {
    let (status, v) = get_json("/api/v1/ready").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["status"], "ok");
    assert_eq!(v["database"], "not_configured");
}

#[tokio::test]
async fn models_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/models").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

/// With a valid-looking Bearer token, missing JWT secret must yield **503** `auth_not_configured` (not **503** `database_error`).
#[tokio::test]
async fn models_auth_not_configured_without_jwt_secret_even_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json_state(
        smoke_state_without_jwt_secret(),
        Request::builder()
            .uri("/api/v1/models")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "auth_not_configured");
}

#[tokio::test]
async fn projects_summary_auth_not_configured_without_jwt_secret_even_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json_state(
        smoke_state_without_jwt_secret(),
        Request::builder()
            .uri("/api/v1/projects/summary")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "auth_not_configured");
}

#[tokio::test]
async fn models_detail_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/models/detail?model_id=1%3Agpt-4o-mini").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

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
    let mut mac = Hmac::<Sha256>::new_from_slice(SM_SECRET.as_bytes()).expect("hmac key");
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

/// Stripe-Signature scheme: valid HMAC within tolerance → missing pool → **`database_error`** (not 401).
#[tokio::test]
async fn billing_webhook_stripe_signature_database_error_when_hmac_ok_but_pool_missing() {
    let _lock = billing_webhook_test_lock().await;
    let prev = std::env::var_os("BILLING_WEBHOOK_SECRET");
    const SM_SECRET: &str = "whsec_contract-smoke-stripe-secret!!";
    std::env::set_var("BILLING_WEBHOOK_SECRET", SM_SECRET);

    let body_json = r#"{"id":"evt_stripe_smoke_no_db"}"#;
    let body = body_json.as_bytes();
    // Use current time so the timestamp is always within the 300 s tolerance window.
    let ts: u64 = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(1_700_000_000);

    let ts_str = ts.to_string();
    let mut mac = Hmac::<Sha256>::new_from_slice(SM_SECRET.as_bytes()).expect("hmac key");
    mac.update(ts_str.as_bytes());
    mac.update(b".");
    mac.update(body);
    let sig_hex = hex::encode(mac.finalize().into_bytes());
    let stripe_hdr = HeaderValue::from_str(&format!("t={ts_str},v1={sig_hex}"))
        .expect("stripe-signature header");

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

    match &prev {
        Some(p) => std::env::set_var("BILLING_WEBHOOK_SECRET", p),
        None => std::env::remove_var("BILLING_WEBHOOK_SECRET"),
    }

    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

/// Stripe-Signature with expired timestamp → **401 invalid_webhook_signature**.
#[tokio::test]
async fn billing_webhook_stripe_signature_rejects_expired_timestamp() {
    let _lock = billing_webhook_test_lock().await;
    let prev = std::env::var_os("BILLING_WEBHOOK_SECRET");
    const SM_SECRET: &str = "whsec_contract-smoke-stripe-secret!!";
    std::env::set_var("BILLING_WEBHOOK_SECRET", SM_SECRET);

    let body_json = r#"{"id":"evt_stripe_smoke_expired"}"#;
    let body = body_json.as_bytes();
    // ts = Unix epoch (year 1970) → always > 300 s in the past
    let ts: u64 = 1;
    let ts_str = ts.to_string();
    let mut mac = Hmac::<Sha256>::new_from_slice(SM_SECRET.as_bytes()).expect("hmac key");
    mac.update(ts_str.as_bytes());
    mac.update(b".");
    mac.update(body);
    let sig_hex = hex::encode(mac.finalize().into_bytes());
    let stripe_hdr = HeaderValue::from_str(&format!("t={ts_str},v1={sig_hex}"))
        .expect("stripe-signature header");

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

    match &prev {
        Some(p) => std::env::set_var("BILLING_WEBHOOK_SECRET", p),
        None => std::env::remove_var("BILLING_WEBHOOK_SECRET"),
    }

    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "invalid_webhook_signature");
}

#[tokio::test]
async fn models_list_ok_with_supabase_style_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/models", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("models list is array");
    assert!(!arr.is_empty(), "embedded catalog must expose models");
    assert!(arr[0].get("id").is_some());
    assert!(arr[0].get("model_name").is_none()); // list entry uses legacy shape: value, type, …
    assert!(arr[0].get("value").is_some());
}

#[tokio::test]
async fn harness_tools_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/harness/tools", &token).await;
    assert_eq!(status, StatusCode::OK);
    let tools = v["tools"].as_array().expect("tools array");
    assert!(!tools.is_empty());
    let names: Vec<&str> = tools.iter().filter_map(|t| t["name"].as_str()).collect();
    assert!(names.contains(&"echo"));
    assert!(names.contains(&"wasm.probe"));
}

#[tokio::test]
async fn skills_summary_ok_with_jwt_when_skills_tree_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/skills/summary", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        v["markdown_file_count"].as_u64().unwrap_or(0) > 0,
        "repo ships backend/data/skills markdown"
    );
}

#[tokio::test]
async fn models_detail_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/models/detail?model_id=1%3Agpt-4o-mini";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["model_name"], "gpt-4o-mini");
    assert_eq!(v["vendor_id"], 1);
    assert_eq!(v["type"], "text");
}

#[tokio::test]
async fn models_text_default_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/models/text-default").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn models_text_default_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/models/text-default", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["legacy_placeholder"], "123");
    assert_eq!(v["default_model_id"], "1:gpt-4o-mini");
}

#[tokio::test]
async fn models_text_default_patch_unauthorized_without_bearer() {
    let (status, v) =
        patch_json_no_bearer("/api/v1/models/text-default", r#"{"model_id":null}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn models_text_default_patch_rejects_unknown_model_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/models/text-default",
        &token,
        r#"{"model_id":"99:nonexistent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn models_text_default_patch_requires_database_with_valid_model_id() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/models/text-default",
        &token,
        r#"{"model_id":"1:gpt-4o-mini"}"#,
    )
    .await;
    // No pool → database_error (quota check passes since model validation is before DB write)
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn models_text_default_patch_null_requires_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/models/text-default",
        &token,
        r#"{"model_id":null}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/vendors/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_vendors_summary_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/vendors/summary", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["source"], "static_catalog_with_user_config");
    let arr = v["vendors"].as_array().expect("vendors array");
    assert!(!arr.is_empty());
    assert!(arr[0]["id"].is_number());
    assert!(arr[0]["name"].as_str().is_some_and(|s| !s.is_empty()));
    assert!(arr[0]["modelCount"].as_i64().is_some_and(|n| n > 0));
}

#[tokio::test]
async fn settings_agent_deploy_list_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/agent-deploy/list", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_agent_deploy_list_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/settings/agent-deploy/list", &token, "{}").await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("array body");
    assert_eq!(arr.len(), 4);
    assert_eq!(arr[0]["key"], "scriptAgent");
    assert_eq!(arr[3]["key"], "ttsDubbing");
    assert_eq!(arr[3]["disabled"], true);
}

#[tokio::test]
async fn settings_agent_deploy_deploy_model_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/agent-deploy/deploy-model",
        &token,
        r#"{"id":1,"name":"剧本Agent","model":"x","modelName":"y","vendorId":null,"desc":"z"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_agent_deploy_set_key_noop_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/settings/agent-deploy/set-key", &token, "{}").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        v["message"],
        "未通过 HTTP 保存密钥；请在服务端环境变量或密钥管理中配置"
    );
}

#[tokio::test]
async fn settings_vendor_model_test_rejects_bad_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/model-test",
        &token,
        r#"{"modelName":"gpt-4o-mini","type":"audio","id":"1"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendor_model_test_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/model-test",
        &token,
        r#"{"modelName":"gpt-4o-mini","type":"text","id":"1"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_add_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/vendors/add", r#"{"tsCode":"export {}"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_vendors_add_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/add",
        &token,
        r#"{"tsCode":"export {}"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_add_rejects_empty_ts_code_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/add",
        &token,
        r#"{"tsCode":"   "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendors_update_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/update",
        &token,
        r#"{"id":"1","displayName":"OpenAI Custom","selectedModels":["gpt-4o-mini"],"settings":{}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_update_rejects_empty_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/update",
        &token,
        r#"{"id":"   ","displayName":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendors_delete_rejects_empty_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/vendors/delete", &token, r#"{"id":"   "}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendors_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/delete",
        &token,
        r#"{"id":"custom-123"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_enable_rejects_empty_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/enable",
        &token,
        r#"{"id":"   ","enable":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendors_enable_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/enable",
        &token,
        r#"{"id":"1","enable":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_update_code_rejects_empty_ts_code_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/update-code",
        &token,
        r#"{"id":"custom-123","tsCode":"   "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendors_update_code_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/update-code",
        &token,
        r#"{"id":"custom-123","tsCode":"export {}"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_code_from_link_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/code-from-link",
        &token,
        r#"{"link":"https://example.com/code.ts"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_code_from_link_rejects_empty_link_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/code-from-link",
        &token,
        r#"{"link":"  "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendors_code_from_link_rejects_non_http_link_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/code-from-link",
        &token,
        r#"{"link":"ftp://example.com/code.ts"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_vendors_credential_requires_encryption_key_with_jwt() {
    let _guard = vendor_credential_test_lock().await;
    std::env::remove_var("TOONFLOW_VENDOR_CREDENTIAL_KEY");
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/credential",
        &token,
        r#"{"vendorId":"openai","apiKey":"sk-test-1234"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
    assert_eq!(v["code"], "not_implemented");
}

#[tokio::test]
async fn settings_vendors_credential_requires_database_with_jwt() {
    let _guard = vendor_credential_test_lock().await;
    std::env::set_var("TOONFLOW_VENDOR_CREDENTIAL_KEY", "test-credential-key");
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/vendors/credential",
        &token,
        r#"{"vendorId":"openai","apiKey":"sk-test-1234"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
    std::env::remove_var("TOONFLOW_VENDOR_CREDENTIAL_KEY");
}

#[tokio::test]
async fn settings_vendors_get_credential_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/vendors/credential/openai", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_vendors_delete_credential_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        delete_json_bearer("/api/v1/settings/vendors/credential/openai", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_danger_delete_all_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/danger/delete-all-data", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_danger_delete_all_not_implemented_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/danger/delete-all-data", &token, "{}").await;
    assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
    assert_eq!(v["code"], "not_implemented");
}

#[tokio::test]
async fn settings_danger_clear_database_not_implemented_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/danger/clear-database", &token, "{}").await;
    assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
    assert_eq!(v["code"], "not_implemented");
}

#[tokio::test]
async fn production_get_production_data_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/production/get-production-data", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn production_get_production_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-production-data",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_get_production_data_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-production-data",
        &token,
        r#"{"ids":[0]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_get_flow_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-flow-data",
        &token,
        r#"{"projectId":1,"episodesId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_save_flow_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/save-flow-data",
        &token,
        r#"{"projectId":1,"episodesId":1,"data":{}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_workbench_generate_video_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/workbench/generate-video",
        &token,
        r#"{"projectId":1,"scriptId":1,"uploadData":[{"id":1,"sources":"assets"}],"prompt":"p","model":"1:x","mode":"std","resolution":"720p","duration":5,"trackId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_polling_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/polling-image",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_export_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/export-image",
        &token,
        r#"{"shotId":[{"id":"1"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_get_assets_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/get-assets-data",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_batch_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/batch-generate-assets-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"assetIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_delete_derivative_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/delete-assets-derivative",
        &token,
        r#"{"projectId":1,"assetIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_polling_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/polling-image",
        &token,
        r#"{"projectId":1,"assetIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_update_url_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/update-assets-url",
        &token,
        r#"{"projectId":1,"assetId":1,"imageUrl":"https://example.com/a.png"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_edit_image_get_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/get-image-flow",
        &token,
        r#"{}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["flowId"], "img-flow-001");
}

#[tokio::test]
async fn production_edit_image_get_image_default_model_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/get-image-default-model",
        &token,
        r#"{}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["model"], "dall-e-3");
}

#[tokio::test]
async fn production_edit_image_save_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/save-image-flow",
        &token,
        r#"{"flowId":"img-flow-001","steps":[{"stepId":"upload","status":"done"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["saved"], true);
}

#[tokio::test]
async fn production_edit_image_update_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/update-image-flow",
        &token,
        r#"{"flowId":"img-flow-001","stepId":"generate","updates":{"status":"done"}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["updated"], true);
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_rejects_empty_flow_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/generate-flow-image",
        &token,
        r#"{"flowId":"   ","prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_rejects_empty_prompt_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/generate-flow-image",
        &token,
        r#"{"flowId":"img-flow-001","prompt":"   "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/generate-flow-image",
        &token,
        r#"{"flowId":"img-flow-001","prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_add_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/add",
        &token,
        r#"{"projectId":1,"scriptId":1,"prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_batch_add_info_rejects_empty_storyboards_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/batch-add-info",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboards":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_get_storyboard_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-storyboard-data",
        &token,
        r#"{"projectId":1,"scriptId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_get_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/get-data",
        &token,
        r#"{"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_edit_info_rejects_empty_prompt_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/edit-info",
        &token,
        r#"{"storyboardId":1,"prompt":"   "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_storyboard_edit_info_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/edit-info",
        &token,
        r#"{"storyboardId":1,"prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_remove_frame_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/remove-frame",
        &token,
        r#"{"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_update_url_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/update-url",
        &token,
        r#"{"storyboardId":1,"imageUrl":"https://example.com/frame.png"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_preview_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/preview-image",
        &token,
        r#"{"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_down_preview_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/down-preview-image",
        &token,
        r#"{"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_get_plan_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/script-agent/get-plan-data",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_agent_get_plan_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/get-plan-data",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_set_plan_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/set-plan-data",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","data":{"storySkeleton":"","adaptationStrategy":"","script":[]}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_update_data_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/update-data",
        &token,
        r#"{"id":1,"data":{"storySkeleton":"","adaptationStrategy":"","script":[{"id":1,"content":""}]}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_generate_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_generate_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_generate_bad_request_empty_prompt_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"  "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_generate_bad_request_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":0,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_generate_accepts_raw_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p","base64":"QUJDRA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_polish_prompt_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/polish-prompt",
        &token,
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"d"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_polish_prompt_bad_request_empty_describe_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/polish-prompt",
        &token,
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"  "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_empty_items_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_zero_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","concurrentCount":0,"items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_accepts_data_uri_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_polish_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_empty_items_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"items":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_zero_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"concurrentCount":0,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_cancel_generate_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets-generate/cancel-generate", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_generate_cancel_generate_bad_request_non_positive_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/cancel-generate",
        &token,
        r#"{"id":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_cancel_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/cancel-generate",
        &token,
        r#"{"id":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn skills_list_ok_with_jwt_when_skills_tree_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/skills", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("skills list is array");
    assert!(!arr.is_empty());
    assert!(arr.iter().any(|e| {
        e.get("path")
            .and_then(Value::as_str)
            .is_some_and(|p| p.ends_with(".md"))
    }));
}

#[tokio::test]
async fn visual_manual_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/visual-manual").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn visual_manual_ok_with_jwt_when_art_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/visual-manual", &token).await;
    assert_eq!(status, StatusCode::OK, "visual_manual={v}");
    let styles = v["styles"].as_array().expect("styles");
    assert!(styles.len() >= 2, "expected multiple art_skills styles");
    assert!(
        styles
            .iter()
            .any(|s| s["stylePath"].as_str() == Some("2D_90s_japanese_anime")),
        "expected 2D_90s_japanese_anime in {styles:?}"
    );
}

#[tokio::test]
async fn visual_manual_post_ok_with_jwt_when_art_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/visual-manual", &token, "{}").await;
    assert_eq!(status, StatusCode::OK, "visual_manual_post={v}");
    let styles = v["styles"].as_array().expect("styles");
    assert!(styles.len() >= 2);
    assert!(styles
        .iter()
        .any(|s| s["stylePath"].as_str() == Some("2D_90s_japanese_anime")));
}

#[tokio::test]
async fn visual_manual_post_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/visual-manual", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_ok_with_jwt_for_known_file() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/skills/content?path=script_execution_script.md";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["path"], "script_execution_script.md");
    assert!(v["content"].as_str().is_some_and(|s| !s.trim().is_empty()));
}

#[tokio::test]
async fn skill_binary_ok_with_jwt_for_smoke_png() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/skills/binary?path=_smoke/binary_probe.png";
    let (status, body, ct) = get_bytes_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(ct.as_deref(), Some("image/png"));
    assert!(body.starts_with(&[0x89, b'P', b'N', b'G']));
}

#[tokio::test]
async fn skill_binary_rejects_markdown_extension_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/skills/binary?path=script_execution_script.md";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_assets_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/assets", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_assets_api_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/get-assets-api",
        r#"{"projectId":1,"type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_assets_api_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-assets-api",
        &token,
        r#"{"projectId":0,"type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_assets_api_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-assets-api",
        &token,
        r#"{"projectId":1,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_add_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/add-assets",
        r#"{"name":"hero","describe":"d","type":"role","projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_add_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/add-assets",
        &token,
        r#"{"name":"hero","describe":"d","type":"role","projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_add_assets_rejects_invalid_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/add-assets",
        &token,
        r#"{"name":"hero","describe":"d","type":"clip","projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_save_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/save-assets",
        r#"{"id":1,"projectId":1,"type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_save_assets_rejects_invalid_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/save-assets",
        &token,
        r#"{"id":1,"projectId":1,"type":"clip"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_save_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/save-assets",
        &token,
        r#"{"id":1,"projectId":1,"type":"role","imageId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_update_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/update-assets",
        r#"{"id":1,"name":"n","describe":"d"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_update_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/update-assets",
        &token,
        r#"{"id":1,"name":"n","describe":"d"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_del_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/del-assets", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_del_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/assets/del-assets", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_batch_delete_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/batch-delete", r#"{"id":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_batch_delete_rejects_empty_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/assets/batch-delete", &token, r#"{"id":[]}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_del_image_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/del-image", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_del_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/assets/del-image", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_image_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/get-image", r#"{"assetsId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_image_rejects_non_positive_assets_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/assets/get-image", &token, r#"{"assetsId":0}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/assets/get-image", &token, r#"{"assetsId":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_upload_clip_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/upload-clip",
        r#"{"projectId":1,"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_upload_clip_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":0,"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_invalid_base64_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","base64Data":"data:image/png;base64,not-base64"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_empty_name_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":" ","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_non_clip_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","type":"role","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_accepts_raw_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","base64Data":"AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_upload_clip_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_material_data_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/get-material-data", r#"{"projectId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_material_data_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-material-data",
        &token,
        r#"{"projectId":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_material_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-material-data",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_batch_generation_data_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/batch-generation-data",
        r#"{"projectId":1,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_batch_generation_data_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/batch-generation-data",
        &token,
        r#"{"projectId":0,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_batch_generation_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/batch-generation-data",
        &token,
        r#"{"projectId":1,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_polling_image_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/polling-image-assets", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_polling_image_assets_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-image-assets",
        &token,
        r#"{"ids":[0]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_polling_image_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-image-assets",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_polling_prompt_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/polling-prompt-assets", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_polling_prompt_assets_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-prompt-assets",
        &token,
        r#"{"ids":[0]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_polling_prompt_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-prompt-assets",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_assets_list_pagination_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/projects/legacy/1/assets?page=1&limit=2", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

/// Combined list filters (parity with legacy **`getAssetsApi`** query surface).
#[tokio::test]
async fn project_assets_list_combined_filters_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/projects/legacy/1/assets?script_legacy_id=1&asset_type=role&name=probe&page=1&limit=2";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_assets_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets",
        &token,
        r#"{"name":"contract_smoke_role","type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_asset_link_put_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        put_empty_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_asset_unlink_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        delete_empty_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_get_by_legacy_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/legacy/1/assets/1",
        &token,
        r#"{"name":"patched"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/projects/legacy/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/novels", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_pagination_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/projects/legacy/1/novels?page=1&limit=5", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/novels",
        &token,
        r#"{"chapter":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/novels/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/legacy/1/novels/1",
        &token,
        r#"{"chapter":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/projects/legacy/1/novels/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_stats_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/stats").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

/// Missing **`Authorization`** must yield **401** before any Postgres pool access (no **503** `database_error` when `DATABASE_URL` is unset).
#[tokio::test]
async fn art_styles_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_cover_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles/legacy/1/cover").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_assets_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/assets").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn corner_scape_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects/legacy/1/assets/corner-scape", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn corner_scape_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets/corner-scape",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn corner_scape_assets_rejects_bad_types_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets/corner-scape",
        &token,
        r#"{"types":["clip"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn corner_scape_assets_accepts_blank_types_entries_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets/corner-scape",
        &token,
        r#"{"types":[" ","\n\t",""]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn corner_scape_assets_accepts_duplicate_types_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets/corner-scape",
        &token,
        r#"{"types":["role","ROLE","scene","scene"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_post_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects/legacy/1/assets/1/images", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/assets/1/images").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/assets/1/images", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_list_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/0/assets/1/images", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_get_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000")
            .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_get_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/legacy/0/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/projects/legacy/1/assets/1/images", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_post_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/projects/legacy/0/assets/1/images", &token, "{}").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer(
        "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000",
        r#"{"sort_index":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
        r#"{"sort_index":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_patch_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/legacy/0/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
        r#"{"sort_index":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer(
        "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer(
        "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_file_get_unauthorized_without_bearer() {
    let (status, v) = get_json(
        "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000/file",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_file_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000/file",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_file_get_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/legacy/0/assets/1/images/00000000-0000-0000-0000-000000000000/file",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_file_get_rejects_malformed_image_id_uuid_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, body, _) = get_bytes_bearer(
        "/api/v1/projects/legacy/1/assets/1/images/not-a-uuid/file",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert!(
        !body.is_empty(),
        "expected error body for invalid uuid path segment"
    );
}

#[tokio::test]
async fn project_assets_list_query_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/legacy/1/assets?script_legacy_id=1&page=1&limit=10").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_filtered_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs?kind=flutter.probe&status=queued").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn usage_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/usage/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn billing_webhook_events_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/webhooks/billing/events").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn billing_webhook_events_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?informational_event=true&provider=stripe&raw_event_id=evt_123&raw_event_id_prefix=evt_&event_type=invoice.payment_failed&provider_event_id=stripe:evt_123&provider_event_id_prefix=stripe:evt_&event_created_from=2026-04-01T00:00:00Z&event_created_to=2026-04-30T23:59:59Z&created_from=2026-04-01T00:00:00Z&created_to=2026-04-30T23:59:59Z&id_min=1&id_max=999999&sort=id_desc&limit=10&offset=0",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn billing_webhook_events_rejects_bad_created_from() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?created_from=not-a-time",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_bad_event_created_from() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_created_from=not-a-time",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_event_created_from_after_to() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_created_from=2026-04-30T23:59:59Z&event_created_to=2026-04-01T00:00:00Z",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_created_from_after_to() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?created_from=2026-04-30T23:59:59Z&created_to=2026-04-01T00:00:00Z",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_id_min_greater_than_id_max() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/webhooks/billing/events?id_min=10&id_max=1", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_event_type() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_type=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id_prefix() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?provider_event_id_prefix=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?provider_event_id=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?raw_event_id=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id_prefix() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?raw_event_id_prefix=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_unknown_provider() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/webhooks/billing/events?provider=foo", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_invalid_sort() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/webhooks/billing/events?sort=unknown", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn prompts_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/prompts").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn prompts_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/prompts/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_query_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/query",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_export_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/scripts/export", r#"{"legacy_ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_kinds_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/kinds").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_kinds_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/kinds/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_status_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/status/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/jobs", r#"{"kind":"flutter.probe","payload":{}}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_list_rejects_invalid_status_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?status=not-a-status", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_rejects_invalid_limit_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?limit=0", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_rejects_negative_offset_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?offset=-1", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_filtered_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/jobs?kind=flutter.probe&status=queued", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/tasks/get-project", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tasks_get_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/tasks/get-project", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_categories_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/tasks/get-task-categories", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_api_bad_page_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/get-task-api",
        &token,
        r#"{"page":0,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn tasks_get_task_api_large_page_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/get-task-api",
        &token,
        r#"{"page":2147483647,"limit":100}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_api_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/get-task-api",
        &token,
        r#"{"page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_int_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/tasks/task-details", &token, r#"{"taskId":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_bad_request_non_uuid_string_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/task-details",
        &token,
        r#"{"taskId":"not-a-uuid"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_numeric_string_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/tasks/task-details", &token, r#"{"taskId":"1"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_uuid_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/task-details",
        &token,
        r#"{"taskId":"550e8400-e29b-41d4-a716-446655440000"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn general_get_single_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/general/get-single-project", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn general_get_single_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/general/get-single-project", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn general_update_project_requires_field_besides_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/general/update-project", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn general_update_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/general/update-project",
        &token,
        r#"{"id":1,"intro":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_get_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/project/get-project", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_get_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/project/get-project", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_delete_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/project/delete-project", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/project/delete-project", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_add_project_unauthorized_without_bearer() {
    let body = r#"{"projectType":"","name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","mode":""}"#;
    let (status, v) = post_json("/api/v1/project/add-project", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"projectType":"","name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","mode":""}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-project", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_edit_project_unauthorized_without_bearer() {
    let body = r#"{"id":1,"name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","projectType":"","mode":""}"#;
    let (status, v) = post_json("/api/v1/project/edit-project", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_edit_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"id":1,"name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","projectType":"","mode":""}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-project", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_query_director_manual_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/project/query-director-manual", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_query_director_manual_ok_with_jwt_when_story_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/project/query-director-manual", &token, "{}").await;
    assert_eq!(status, StatusCode::OK, "query_director_manual={v}");
    let data = v["data"].as_array().expect("data array");
    assert!(data.len() >= 2, "expected story_skills rows");
    assert!(data
        .iter()
        .any(|row| { row["directorManual"].as_str() == Some("Family_warmth") }));
}

#[tokio::test]
async fn project_add_director_manual_unauthorized_without_bearer() {
    let body = r#"{"name":"n","images":[],"directorManual":"n","data":[]}"#;
    let (status, v) = post_json("/api/v1/project/add-director-manual", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_director_manual_rejects_duplicate_bundle_folder() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"n","images":[],"directorManual":"Family_warmth","data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-director-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_edit_director_manual_not_found_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let body =
        r#"{"name":"t","directorManual":"__missing_director_manual_zz","images":[],"data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-director-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert_eq!(v["message"], "导演手册不存在");
}

#[tokio::test]
async fn project_delete_director_manual_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/project/delete-director-manual",
        r#"{"name":"Family_warmth"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_director_manual_rejects_pure_digit_name() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-director-manual",
        &token,
        r#"{"name":"123"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_delete_director_manual_ok_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-director-manual",
        &token,
        r#"{"name":"__contract_smoke_missing_story_skill"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "删除成功");
}

#[tokio::test]
async fn project_add_visual_manual_unauthorized_without_bearer() {
    let body = r#"{"name":"n","images":[],"stylePath":"n","data":[]}"#;
    let (status, v) = post_json("/api/v1/project/add-visual-manual", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_visual_manual_rejects_duplicate_bundle_style() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"n","images":[],"stylePath":"2D_90s_japanese_anime","data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-visual-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_edit_visual_manual_not_found_for_missing_style() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"t","stylePath":"__missing_visual_style_xx","images":[],"data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-visual-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert_eq!(v["message"], "视觉手册不存在");
}

#[tokio::test]
async fn project_delete_visual_manual_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/project/delete-visual-manual",
        r#"{"name":"2D_90s_japanese_anime"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_visual_manual_rejects_pure_digit_name() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-visual-manual",
        &token,
        r#"{"name":"42"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_delete_visual_manual_ok_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-visual-manual",
        &token,
        r#"{"name":"__contract_smoke_missing_art_style"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "删除成功");
}

#[tokio::test]
async fn scripts_get_script_api_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/scripts/get-script-api", r#"{"projectId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_get_script_api_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/scripts/get-script-api",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_get_novel_data_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/get-novel-data", r#"{"projectId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_get_novel_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel-data",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_get_novel_index_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel-index",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_get_novel_event_state_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/get-novel-event-state", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_get_novel_event_state_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel-event-state",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novel_events_generate_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/novels/events/generate-events",
        r#"{"projectId":1,"novelIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novel_events_generate_validates_payload_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/generate-events",
        &token,
        r#"{"projectId":1,"novelIds":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/generate-events",
        &token,
        r#"{"projectId":1,"novelIds":[1],"concurrentCount":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novel_events_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/generate-events",
        &token,
        r#"{"projectId":1,"novelIds":[1],"concurrentCount":5}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_batch_delete_empty_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/novels/batch-delete", &token, r#"{"ids":[]}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_batch_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/novels/batch-delete", &token, r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novel_events_get_events_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/novels/events/get-events",
        r#"{"projectId":1,"page":1,"limit":20}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novel_events_get_events_validates_payload_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":0,"page":1,"limit":20}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":1,"page":0,"limit":20}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":1,"page":1,"limit":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novel_events_get_events_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":1,"page":1,"limit":20,"search":"事件"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novel_events_batch_delete_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/events/batch-delete", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novel_events_batch_delete_validates_payload_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/batch-delete",
        &token,
        r#"{"ids":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novel_events_batch_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/batch-delete",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_events_batch_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/novel-events/batch-delete",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_get_novel_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/novels/get-novel",
        r#"{"projectId":1,"page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_get_novel_bad_page_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel",
        &token,
        r#"{"projectId":1,"page":0,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_get_novel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel",
        &token,
        r#"{"projectId":1,"page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_add_novel_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/add-novel", r#"{"projectId":1,"data":[]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_add_novel_empty_data_ok_with_jwt_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/add-novel",
        &token,
        r#"{"projectId":1,"data":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "新增原文成功");
}

#[tokio::test]
async fn novels_add_novel_with_rows_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"projectId":1,"data":[{"index":1,"reel":"","chapter":"c","chapterData":"d"}]}"#;
    let (status, v) = post_json_bearer("/api/v1/novels/add-novel", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_delete_novel_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/delete-novel", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_delete_novel_bad_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/novels/delete-novel", &token, r#"{"id":0}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_delete_novel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/novels/delete-novel", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_update_novel_unauthorized_without_bearer() {
    let body = r#"{"id":1,"index":1,"reel":"","chapter":"c","chapterData":"d","event":""}"#;
    let (status, v) = post_json("/api/v1/novels/update-novel", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_update_novel_bad_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"id":0,"index":1,"reel":"","chapter":"c","chapterData":"d","event":""}"#;
    let (status, v) = post_json_bearer("/api/v1/novels/update-novel", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_update_novel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"id":1,"index":1,"reel":"","chapter":"c","chapterData":"d","event":""}"#;
    let (status, v) = post_json_bearer("/api/v1/novels/update-novel", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/jobs",
        &token,
        r#"{"kind":"flutter.probe","payload":{}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn job_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn job_cancel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/cancel");
    let (status, v) = post_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn job_retry_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/retry");
    let (status, v) = post_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_kinds_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/kinds", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_kinds_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/kinds/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_status_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/status/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn usage_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/usage/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/prompts", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/prompts/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer("/api/v1/prompts/1", &token, r#"{"data":"patched"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_patch_unknown_legacy_returns_404_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer("/api/v1/prompts/99", &token, r#"{"data":"x"}"#).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}

#[tokio::test]
async fn prompts_get_unknown_legacy_returns_404_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/prompts/99", &token).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}

#[tokio::test]
async fn agents_memory_query_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/query",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn agents_memory_clear_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/clear",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn agents_memory_append_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/append",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","content":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_export_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/scripts/export", &token, r#"{"legacy_ids":[1]}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_state_poll_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/scripts/extract-state/poll",
        &token,
        r#"{"legacy_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/scripts/extract-assets",
        &token,
        r#"{"project_legacy_id":1,"script_legacy_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/projects", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_state_poll_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-state/poll",
        r#"{"legacy_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_extract_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-assets",
        r#"{"project_legacy_id":1,"script_legacy_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboards_by_script_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/scripts/legacy/1/storyboards").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/storyboards/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn me_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/me").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

/// **`/api/v1/me`** does not require a Postgres pool: without **`DATABASE_URL`** it still returns **200** with default **`plan_tier`** (differs from most authenticated routes that return **503** `database_error`).
#[tokio::test]
async fn me_ok_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/me", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["plan_tier"], "free");
    assert!(
        v["sub"].as_str().is_some_and(|s| !s.is_empty()),
        "expected sub in me response"
    );
    // Without pool: daily_job_quota is the free-tier default (positive), jobs_today absent.
    assert!(
        v["daily_job_quota"].as_i64().is_some_and(|n| n > 0),
        "expected positive daily_job_quota without pool"
    );
    assert!(
        v["jobs_today"].is_null(),
        "jobs_today should be absent without pool"
    );
    assert!(
        v["subscription_status"].is_null(),
        "subscription_status should be absent without pool"
    );
    assert!(
        v["subscription_current_period_end_at"].is_null(),
        "subscription_current_period_end_at should be absent without pool"
    );
}

#[tokio::test]
async fn settings_dev_switch_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/dev/switch-ai-tool").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_dev_switch_get_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/dev/switch-ai-tool", &token).await;
    assert_eq!(status, StatusCode::OK);
    let val = v["value"].as_str().expect("value");
    assert!(val == "0" || val == "1");
}

#[tokio::test]
async fn settings_dev_switch_put_updates_process_local_value_with_jwt() {
    let state = smoke_state();
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json_state(
        state.clone(),
        Request::builder()
            .method(Method::PUT)
            .uri("/api/v1/settings/dev/switch-ai-tool")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(r#"{"value":"1"}"#.to_string()))
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["value"], "1");

    let (status, v) = oneshot_json_state(
        state,
        Request::builder()
            .uri("/api/v1/settings/dev/switch-ai-tool")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["value"], "1");
}

#[tokio::test]
async fn settings_dev_switch_put_rejects_non_binary_value_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/settings/dev/switch-ai-tool",
        &token,
        r#"{"value":"2"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_memory_config_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/memory-config").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_memory_config_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/memory-config", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_memory_config_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"messagesPerSummary":10,"shortTermLimit":5,"summaryMaxLength":500,"summaryLimit":10,"ragLimit":3,"deepRetrieveSummaryLimit":5,"modelOnnxFile":["all-MiniLM-L6-v2","onnx","model_fp16.onnx"],"modelDtype":"fp16"}"#;
    let (status, v) = post_json_bearer("/api/v1/settings/memory-config", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_memory_config_clear_agent_memories_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/settings/memory-config/clear-agent-memories",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_memory_config_clear_agent_memories_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/memory-config/clear-agent-memories",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_about_check_update_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/settings/about/check-update",
        r#"{"source":"toonflow"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_about_check_update_stub_ok_with_jwt() {
    let _guard = settings_about_env_test_lock().await;
    std::env::remove_var("TOONFLOW_UPDATE_LATEST_VERSION");
    std::env::remove_var("TOONFLOW_UPDATE_TIME");
    std::env::remove_var("TOONFLOW_UPDATE_TOONFLOW_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITHUB_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITEE_URL");
    std::env::remove_var("TOONFLOW_UPDATE_ATOMGIT_URL");
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/check-update",
        &token,
        r#"{"source":"github"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["needUpdate"], false);
    assert_eq!(v["reinstall"], false);
    assert!(v["latestVersion"].as_str().is_some_and(|s| !s.is_empty()));
    assert!(v["time"].as_str().is_some_and(|s| !s.is_empty()));
    assert!(v.get("url").is_none() || v["url"].is_null());
}

#[tokio::test]
async fn settings_about_check_update_uses_env_manifest_with_jwt() {
    let _guard = settings_about_env_test_lock().await;
    std::env::set_var("TOONFLOW_UPDATE_LATEST_VERSION", "0.1.1");
    std::env::set_var("TOONFLOW_UPDATE_TIME", "2026-04-08T08:30:00Z");
    std::env::set_var(
        "TOONFLOW_UPDATE_GITHUB_URL",
        "https://example.com/toonflow-0.1.1.zip",
    );
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/check-update",
        &token,
        r#"{"source":"github"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["needUpdate"], true);
    assert_eq!(v["reinstall"], false);
    assert_eq!(v["latestVersion"], "0.1.1");
    let parsed_time =
        chrono::DateTime::parse_from_rfc3339(v["time"].as_str().expect("time should be string"))
            .expect("time should be rfc3339");
    assert_eq!(
        parsed_time.to_utc().to_rfc3339(),
        "2026-04-08T08:30:00+00:00"
    );
    assert_eq!(v["url"], "https://example.com/toonflow-0.1.1.zip");
    std::env::remove_var("TOONFLOW_UPDATE_LATEST_VERSION");
    std::env::remove_var("TOONFLOW_UPDATE_TIME");
    std::env::remove_var("TOONFLOW_UPDATE_TOONFLOW_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITHUB_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITEE_URL");
    std::env::remove_var("TOONFLOW_UPDATE_ATOMGIT_URL");
}

#[tokio::test]
async fn settings_about_download_app_noop_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/download-app",
        &token,
        r#"{"url":"https://example.com/app.dmg","reinstall":true}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert!(v["message"].as_str().is_some_and(|s| s.contains("Flutter")));
}

#[tokio::test]
async fn settings_about_download_app_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/settings/about/download-app",
        r#"{"url":"https://example.com/app.dmg","reinstall":false}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_about_download_app_rejects_bad_url_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/download-app",
        &token,
        r#"{"url":"not-a-url","reinstall":false}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skills_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skills_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/content?path=script_execution_script.md").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_binary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/binary?path=_smoke/binary_probe.png").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_put_unauthorized_without_bearer() {
    let (status, v) = put_json(
        "/api/v1/skills/content",
        r#"{"path":"script_execution_script.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_put_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"../Cargo.toml","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_put_rejects_missing_file_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"__no_such_skill_file__.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_post_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/skills/content", r#"{"path":"x.md","content":"y"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_post_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"../README.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_post_conflict_when_file_exists() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"script_execution_script.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(v["code"], "conflict");
}

#[tokio::test]
async fn skill_content_post_get_delete_roundtrip() {
    let token = test_jwt(Uuid::nil());
    let name = format!("__contract_post_skill_{}.md", Uuid::new_v4());
    let body = serde_json::json!({
        "path": name.clone(),
        "content": "smoke_post_body",
    })
    .to_string();
    let (status, v) = post_json_bearer("/api/v1/skills/content", &token, &body).await;
    assert_eq!(status, StatusCode::CREATED, "v={v}");
    assert_eq!(v["path"], name);
    assert_eq!(v["content"], "smoke_post_body");

    let uri = format!("/api/v1/skills/content?path={name}");
    let (gstatus, gv) = get_json_bearer(&uri, &token).await;
    assert_eq!(gstatus, StatusCode::OK, "gv={gv}");
    assert_eq!(gv["content"], "smoke_post_body");

    let (dstatus, dv) = delete_json_bearer(&uri, &token).await;
    assert_eq!(dstatus, StatusCode::NO_CONTENT, "dv={dv}");
    assert!(dv.is_null());

    let (gone_status, _) = get_json_bearer(&uri, &token).await;
    assert_eq!(gone_status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn skill_content_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_json_no_bearer("/api/v1/skills/content?path=script_execution_script.md").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_delete_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_json_bearer("/api/v1/skills/content?path=../Cargo.toml", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_delete_not_found_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_json_bearer(
        "/api/v1/skills/content?path=__no_such_skill_for_delete__.md",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}

#[tokio::test]
async fn harness_tools_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/harness/tools").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_by_id_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}");
    let (status, v) = get_json(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_cancel_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/cancel");
    let (status, v) = post_empty_no_bearer(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_retry_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/retry");
    let (status, v) = post_empty_no_bearer(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer("/api/v1/projects/legacy/1", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/projects/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_by_legacy_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        patch_json_bearer("/api/v1/projects/legacy/1", &token, r#"{"name":"smoke"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/projects/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_stats_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/stats", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/novels").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_list_search_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/legacy/1/novels?search=smoke&page=1&limit=10").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects/legacy/1/novels", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novel_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/novels/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novel_patch_unauthorized_without_bearer() {
    let (status, v) =
        patch_json_no_bearer("/api/v1/projects/legacy/1/novels/1", r#"{"chapter":"x"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novel_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/projects/legacy/1/novels/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn create_script_under_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects/legacy/1/scripts", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn create_script_under_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/projects/legacy/1/scripts", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/scripts/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer("/api/v1/scripts/legacy/1", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/scripts/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/scripts/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        patch_json_bearer("/api/v1/scripts/legacy/1", &token, r#"{"name":"smoke"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/scripts/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_create_under_script_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/scripts/legacy/1/storyboards", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer("/api/v1/storyboards/legacy/1", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/storyboards/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboards_list_by_script_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/scripts/legacy/1/storyboards", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_create_under_script_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/scripts/legacy/1/storyboards", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/storyboards/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/storyboards/legacy/1",
        &token,
        r#"{"prompt":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/storyboards/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_styles_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/art-styles", r#"{"name":"smoke"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer("/api/v1/art-styles/legacy/1", r#"{"label":"x"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/art-styles/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_create_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/legacy/1/assets",
        r#"{"name":"smoke","type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_patch_unauthorized_without_bearer() {
    let (status, v) =
        patch_json_no_bearer("/api/v1/projects/legacy/1/assets/1", r#"{"name":"x"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/projects/legacy/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_clear_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/clear",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_append_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/append",
        r#"{"projectId":1,"agentType":"scriptAgent","content":"hi"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_asset_link_put_unauthorized_without_bearer() {
    let (status, v) = put_empty_no_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_asset_unlink_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_styles_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_styles_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/art-styles", &token, r#"{"name":"smoke_style"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_extract_prompt_requires_llm_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/art-styles/extract-prompt",
        &token,
        r#"{"images":["https://example.com/contract-smoke.png"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "llm_not_configured");
}

#[tokio::test]
async fn art_style_extract_prompt_empty_images_returns_bad_request_without_llm() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/art-styles/extract-prompt",
        &token,
        r#"{"images":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn art_style_extract_prompt_blank_image_returns_bad_request_without_llm() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/art-styles/extract-prompt",
        &token,
        r#"{"images":["  \t  "]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn art_style_extract_prompt_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/art-styles/extract-prompt",
        r#"{"images":["https://example.com/x.png"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_cover_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles/legacy/1/cover", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        patch_json_bearer("/api/v1/art-styles/legacy/1", &token, r#"{"label":"x"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/art-styles/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
