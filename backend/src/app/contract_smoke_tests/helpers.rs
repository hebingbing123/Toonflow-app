use std::net::SocketAddr;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::OnceLock;

use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::{Method, Request, StatusCode};
use serde_json::Value;
use tokio::sync::RwLock;
use tower::ServiceExt;
use uuid::Uuid;

pub(super) use crate::app::billing_webhook_events_list_env::BillingWebhookEventsListEnvGuard;

use crate::app::build_router;
use crate::app::jwt_fixture;
use crate::state::WsNotifyHub;
use crate::state::{AppState, MemoryConfig};

/// Large enough for **`GET /api/v1/visual-manual`** (many bundled Markdown files).
pub(super) const MAX_JSON: usize = 2 * 1024 * 1024;
/// Response bodies for **`GET /api/v1/skills/binary`** smoke (single reference image).
pub(super) const MAX_PROBE_BYTES: usize = 512 * 1024;
/// Shared with [`jwt_fixture::encode_supabase_style`]; must satisfy Supabase-style `aud` + HS256 verify.
pub(super) const TEST_JWT_SECRET: &[u8] = b"contract-smoke-jwt-secret-bytes-32chars!";
pub(super) const NIL_JOB_UUID: &str = "00000000-0000-0000-0000-000000000000";

/// Serialize billing webhook tests that read or write **`BILLING_WEBHOOK_SECRET`** (avoids parallel **`cargo test`** flakes).
pub(super) static BILLING_WEBHOOK_TEST_MUTEX: OnceLock<tokio::sync::Mutex<()>> = OnceLock::new();

/// Serialize **`TOONFLOW_INTERNAL_OPS_TOKEN`** mutation in internal-ops contract tests.
static INTERNAL_OPS_QUEUE_STATS_MUTEX: OnceLock<Mutex<()>> = OnceLock::new();

pub(super) fn internal_ops_token_test_lock() -> std::sync::MutexGuard<'static, ()> {
    INTERNAL_OPS_QUEUE_STATS_MUTEX
        .get_or_init(|| Mutex::new(()))
        .lock()
        .expect("internal ops queue stats test mutex poisoned")
}

pub(super) fn internal_ops_queue_stats_test_lock() -> std::sync::MutexGuard<'static, ()> {
    internal_ops_token_test_lock()
}
pub(super) async fn billing_webhook_test_lock() -> tokio::sync::MutexGuard<'static, ()> {
    BILLING_WEBHOOK_TEST_MUTEX
        .get_or_init(|| tokio::sync::Mutex::new(()))
        .lock()
        .await
}

pub(super) fn test_addr() -> SocketAddr {
    SocketAddr::from(([127, 0, 0, 1], 42_042))
}

pub(super) fn smoke_state() -> AppState {
    AppState {
        metrics_registry: Arc::new(crate::http_kit::metrics::MetricsRegistry::default()),
        pool: None,
        jwt_secret: Some(TEST_JWT_SECRET.to_vec()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
        local_video_export_dir: None,
        local_voiceover_audio_dir: None,
    }
}

/// Same as [`smoke_state`] but JWT verification is disabled (production analogue: **`SUPABASE_JWT_SECRET` unset**).
pub(super) fn smoke_state_without_jwt_secret() -> AppState {
    AppState {
        metrics_registry: Arc::new(crate::http_kit::metrics::MetricsRegistry::default()),
        pool: None,
        jwt_secret: None,
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
        local_video_export_dir: None,
        local_voiceover_audio_dir: None,
    }
}

pub(super) fn test_jwt(sub: Uuid) -> String {
    jwt_fixture::encode_supabase_style(sub, TEST_JWT_SECRET)
}

pub(super) async fn oneshot_json_state(state: AppState, req: Request<Body>) -> (StatusCode, Value) {
    let app = build_router(state);
    let res = app.oneshot(req).await.unwrap();
    let status = res.status();
    let body = axum::body::to_bytes(res.into_body(), MAX_JSON)
        .await
        .unwrap();
    let v: Value = serde_json::from_slice(&body).expect("response body is json");
    (status, v)
}

pub(super) async fn oneshot_json(req: Request<Body>) -> (StatusCode, Value) {
    oneshot_json_state(smoke_state(), req).await
}

pub(super) async fn get_json(uri: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .uri(uri)
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

pub(super) async fn get_json_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
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

/// `GET` with optional **`X-Toonflow-Internal-Token`** (Q2 运维队列 stats)。
pub(super) async fn get_json_internal_ops(
    uri: &str,
    internal_token: Option<&str>,
) -> (StatusCode, Value) {
    let mut req = Request::builder()
        .uri(uri)
        .extension(ConnectInfo(test_addr()));
    if let Some(t) = internal_token {
        req = req.header("x-toonflow-internal-token", t);
    }
    oneshot_json(req.body(Body::empty()).unwrap()).await
}

pub(super) async fn get_bytes_bearer(
    uri: &str,
    token: &str,
) -> (StatusCode, Vec<u8>, Option<String>) {
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

pub(super) async fn post_json_bearer(
    uri: &str,
    token: &str,
    json_body: &str,
) -> (StatusCode, Value) {
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

pub(super) async fn post_json(uri: &str, json_body: &str) -> (StatusCode, Value) {
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

pub(super) async fn put_json(uri: &str, json_body: &str) -> (StatusCode, Value) {
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

pub(super) async fn patch_json_no_bearer(uri: &str, json_body: &str) -> (StatusCode, Value) {
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

pub(super) async fn post_empty_no_bearer(uri: &str) -> (StatusCode, Value) {
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

pub(super) async fn post_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
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

/// POST **`application/wasm`** or **`application/octet-stream`** binary body (`MAX_PROBE_BYTES`).
pub(super) async fn post_bytes_bearer_octet(
    uri: &str,
    token: &str,
    mime: &str,
    body: &[u8],
) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, mime)
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(body.to_vec()))
            .unwrap(),
    )
    .await
}

pub(super) async fn put_empty_no_bearer(uri: &str) -> (StatusCode, Value) {
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

pub(super) async fn delete_empty_no_bearer(uri: &str) -> (StatusCode, Value) {
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

pub(super) async fn patch_json_bearer(
    uri: &str,
    token: &str,
    json_body: &str,
) -> (StatusCode, Value) {
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

pub(super) async fn put_json_bearer(
    uri: &str,
    token: &str,
    json_body: &str,
) -> (StatusCode, Value) {
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

pub(super) async fn put_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
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

pub(super) async fn delete_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
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
pub(super) async fn delete_json_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
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

pub(super) async fn delete_json_no_bearer(uri: &str) -> (StatusCode, Value) {
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
