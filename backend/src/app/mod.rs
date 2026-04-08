//! HTTP router composition and core JSON routes (`/health`, `/api/v1/me`, …).

mod handlers;
mod router;

pub use router::build_router;

#[cfg(test)]
mod jwt_fixture {
    use chrono::Utc;
    use jsonwebtoken::{encode, EncodingKey, Header};
    use serde::Serialize;
    use uuid::Uuid;

    #[derive(Serialize)]
    struct SmokeJwtClaims {
        sub: String,
        exp: i64,
        aud: &'static str,
    }

    pub(crate) fn encode_supabase_style(sub: Uuid, secret: &[u8]) -> String {
        encode(
            &Header::default(),
            &SmokeJwtClaims {
                sub: sub.to_string(),
                exp: Utc::now().timestamp() + 86_400,
                aud: "authenticated",
            },
            &EncodingKey::from_secret(secret),
        )
        .expect("encode test jwt")
    }
}

#[cfg(test)]
static VENDOR_CREDENTIAL_TEST_MUTEX: std::sync::OnceLock<tokio::sync::Mutex<()>> =
    std::sync::OnceLock::new();

#[cfg(test)]
async fn vendor_credential_test_lock() -> tokio::sync::MutexGuard<'static, ()> {
    VENDOR_CREDENTIAL_TEST_MUTEX
        .get_or_init(|| tokio::sync::Mutex::new(()))
        .lock()
        .await
}

#[cfg(test)]
mod contract_smoke_tests {
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
        let (status, v) =
            post_json_bearer("/api/v1/settings/agent-deploy/list", &token, "{}").await;
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
        let (status, v) =
            post_json_bearer("/api/v1/settings/agent-deploy/set-key", &token, "{}").await;
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
        let (status, v) =
            post_json("/api/v1/settings/vendors/add", r#"{"tsCode":"export {}"}"#).await;
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
        let (status, v) =
            get_json_bearer("/api/v1/settings/vendors/credential/openai", &token).await;
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
        let (status, v) =
            post_json("/api/v1/production/get-production-data", r#"{"ids":[1]}"#).await;
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
        let (status, v) =
            get_json_bearer("/api/v1/projects/legacy/1/assets/1/images", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn asset_image_list_rejects_non_positive_ids_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            get_json_bearer("/api/v1/projects/legacy/0/assets/1/images", &token).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert_eq!(v["code"], "bad_request");
    }

    #[tokio::test]
    async fn asset_image_get_unauthorized_without_bearer() {
        let (status, v) = get_json(
            "/api/v1/projects/legacy/1/assets/1/images/00000000-0000-0000-0000-000000000000",
        )
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
    async fn billing_webhook_events_rejects_invalid_sort() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            get_json_bearer("/api/v1/webhooks/billing/events?sort=unknown", &token).await;
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
        let (status, v) =
            post_json("/api/v1/jobs", r#"{"kind":"flutter.probe","payload":{}}"#).await;
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
        let (status, v) =
            post_json_bearer("/api/v1/project/query-director-manual", &token, "{}").await;
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
        let (status, v) =
            post_json_bearer("/api/v1/project/add-director-manual", &token, body).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert_eq!(v["code"], "bad_request");
    }

    #[tokio::test]
    async fn project_edit_director_manual_not_found_for_missing_folder() {
        let token = test_jwt(Uuid::nil());
        let body =
            r#"{"name":"t","directorManual":"__missing_director_manual_zz","images":[],"data":[]}"#;
        let (status, v) =
            post_json_bearer("/api/v1/project/edit-director-manual", &token, body).await;
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
        let (status, v) =
            post_json_bearer("/api/v1/project/edit-visual-manual", &token, body).await;
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
        let (status, v) =
            post_json("/api/v1/novels/add-novel", r#"{"projectId":1,"data":[]}"#).await;
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
        let body =
            r#"{"projectId":1,"data":[{"index":1,"reel":"","chapter":"c","chapterData":"d"}]}"#;
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
        let (status, v) =
            post_json_bearer("/api/v1/novels/delete-novel", &token, r#"{"id":0}"#).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert_eq!(v["code"], "bad_request");
    }

    #[tokio::test]
    async fn novels_delete_novel_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            post_json_bearer("/api/v1/novels/delete-novel", &token, r#"{"id":1}"#).await;
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
        let (status, v) =
            patch_json_bearer("/api/v1/prompts/1", &token, r#"{"data":"patched"}"#).await;
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
        let parsed_time = chrono::DateTime::parse_from_rfc3339(
            v["time"].as_str().expect("time should be string"),
        )
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
        let (status, v) =
            post_json("/api/v1/skills/content", r#"{"path":"x.md","content":"y"}"#).await;
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
        let (status, v) =
            delete_json_bearer("/api/v1/skills/content?path=../Cargo.toml", &token).await;
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
        let (status, v) =
            post_json_bearer("/api/v1/scripts/legacy/1/storyboards", &token, "{}").await;
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
        let (status, v) =
            patch_json_no_bearer("/api/v1/art-styles/legacy/1", r#"{"label":"x"}"#).await;
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
        let (status, v) =
            delete_empty_no_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1").await;
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
}

/// Postgres-backed contract checks (opt-in: **`#[ignore]`** so default **`cargo test`** stays DB-free).
#[cfg(test)]
mod pg_contract_tests {
    use std::net::SocketAddr;
    use std::path::PathBuf;
    use std::sync::Arc;

    use axum::body::Body;
    use axum::extract::ConnectInfo;
    use axum::http::header;
    use axum::http::{Method, Request, StatusCode};
    use axum::response::Response;
    use serde_json::Value;
    use sqlx::postgres::PgPoolOptions;
    use sqlx::types::Json;
    use sqlx::PgPool;
    use tokio::sync::RwLock;
    use tower::ServiceExt;
    use uuid::Uuid;

    use super::build_router;
    use super::jwt_fixture;
    use super::vendor_credential_test_lock;
    use crate::jobs::{
        JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH,
        JOB_KIND_ASSET_POLISH_PROMPT, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST,
    };
    use crate::notify_hub::WsNotifyHub;
    use crate::state::{AppState, MemoryConfig};

    const MAX_JSON: usize = 65_536;
    const TEST_JWT_SECRET: &[u8] = b"contract-smoke-jwt-secret-bytes-32chars!";
    /// JWT `sub` and `app_project.owner_user_id` for this run.
    const CONTRACT_USER_SUB: &str = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

    /// Isolated legacy ids for **`promote_staging_populates_assets_and_links`** (avoid API allocator range).
    const PROMO_LEGACY_USER: i32 = 5_010_000;
    const PROMO_PROJECT_LEG: i32 = 5_010_001;
    const PROMO_SCRIPT_LEG: i32 = 5_010_002;
    const PROMO_ASSET_LEG: i32 = 5_010_003;
    const PROMO_ART_STYLE_LEG: i32 = 5_010_004;
    const PROMO_IMAGE_LEG: i32 = 5_010_005;

    async fn cleanup_promote_staging_fixtures(pool: &PgPool) {
        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let _ = sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
            .bind(sub)
            .execute(pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(PROMO_PROJECT_LEG)
            .execute(pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_art_style WHERE legacy_id = $1")
            .bind(PROMO_ART_STYLE_LEG)
            .execute(pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.legacy_user_map WHERE legacy_user_id = $1")
            .bind(PROMO_LEGACY_USER)
            .execute(pool)
            .await;
        let _ = sqlx::query(
            r#"DELETE FROM legacy_staging.snapshot
               WHERE source_row_key IN ('pg_promote_proj','pg_promote_script','pg_promote_asset','pg_promote_script_asset','pg_promote_art_style','pg_promote_prompt','pg_promote_image')"#,
        )
        .execute(pool)
        .await;
    }

    async fn cleanup_quality_reviews(pool: &PgPool, review_ids: &[Uuid]) {
        if review_ids.is_empty() {
            return;
        }

        let _ = sqlx::query("DELETE FROM public.app_quality_review WHERE id = ANY($1)")
            .bind(review_ids)
            .execute(pool)
            .await;
    }

    async fn cleanup_jobs(pool: &PgPool, job_ids: &[Uuid]) {
        if job_ids.is_empty() {
            return;
        }

        let _ = sqlx::query("DELETE FROM public.app_usage_event WHERE source_job_id = ANY($1)")
            .bind(job_ids)
            .execute(pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_generation_job WHERE id = ANY($1)")
            .bind(job_ids)
            .execute(pool)
            .await;
    }

    async fn cleanup_billing_webhook_events(pool: &PgPool, provider_event_ids: &[String]) {
        if provider_event_ids.is_empty() {
            return;
        }

        let _ = sqlx::query(
            "DELETE FROM public.app_billing_webhook_event WHERE provider_event_id = ANY($1)",
        )
        .bind(provider_event_ids)
        .execute(pool)
        .await;
    }

    fn test_addr() -> SocketAddr {
        SocketAddr::from(([127, 0, 0, 1], 42_043))
    }

    async fn read_json_response(res: Response) -> (StatusCode, Value) {
        let status = res.status();
        let bytes = axum::body::to_bytes(res.into_body(), MAX_JSON)
            .await
            .unwrap();
        let v = if bytes.is_empty() {
            Value::Null
        } else {
            serde_json::from_slice(&bytes).expect("response json")
        };
        (status, v)
    }

    async fn read_bytes_response(
        res: Response,
        max: usize,
    ) -> (StatusCode, Vec<u8>, Option<String>) {
        let status = res.status();
        let ct = res
            .headers()
            .get(header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .map(str::to_string);
        let bytes = axum::body::to_bytes(res.into_body(), max).await.unwrap();
        (status, bytes.to_vec(), ct)
    }

    fn contract_state(pool: sqlx::PgPool, jwt_secret: String) -> AppState {
        AppState {
            pool: Some(pool),
            jwt_secret: Some(jwt_secret.into_bytes()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
            switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
            local_asset_image_dir: None,
            local_art_style_cover_dir: None,
        }
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

    fn test_jwt(sub: Uuid) -> String {
        jwt_fixture::encode_supabase_style(sub, TEST_JWT_SECRET)
    }

    async fn oneshot_json(req: Request<Body>) -> (StatusCode, Value) {
        let app = build_router(smoke_state());
        let res = app.oneshot(req).await.unwrap();
        read_json_response(res).await
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

    fn contract_state_with_local_dir(
        pool: sqlx::PgPool,
        jwt_secret: String,
        dir: PathBuf,
    ) -> AppState {
        AppState {
            pool: Some(pool),
            jwt_secret: Some(jwt_secret.into_bytes()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
            switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
            local_asset_image_dir: Some(dir),
            local_art_style_cover_dir: None,
        }
    }

    fn contract_state_with_local_art_style_dir(
        pool: sqlx::PgPool,
        jwt_secret: String,
        dir: PathBuf,
    ) -> AppState {
        AppState {
            pool: Some(pool),
            jwt_secret: Some(jwt_secret.into_bytes()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
            switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
            local_asset_image_dir: None,
            local_art_style_cover_dir: Some(dir),
        }
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn projects_create_stats_delete_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");
        let pool_sql = pool.clone();

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool, secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "body={created}");
        let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, stats) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "stats={stats}");
        assert_eq!(stats["script_count"], 0);
        assert_eq!(stats["storyboard_count"], 0);
        assert_eq!(stats["role_count"], 0);
        assert_eq!(stats["novel_count"], 0);
        assert_eq!(stats["video_count"], 0);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, assets_body) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "assets={assets_body}");
        assert!(assets_body["items"].is_array());
        assert_eq!(
            assets_body["total"].as_i64().unwrap_or(-1),
            assets_body["items"]
                .as_array()
                .map(|a| a.len() as i64)
                .unwrap_or(-2),
            "unpaged list: total matches items length"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/scripts"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, script_row) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "script={script_row}");
        let script_leg = script_row["legacy_id"].as_i64().expect("script legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"name":"pg_contract_role_asset","type":"role"}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, asset_row) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "asset={asset_row}");
        let asset_leg = asset_row["legacy_id"].as_i64().expect("asset legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, one_asset) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "one_asset={one_asset}");
        assert_eq!(
            one_asset["legacy_id"].as_i64().expect("legacy_id"),
            i64::from(asset_leg)
        );
        assert_eq!(one_asset["name"].as_str(), Some("pg_contract_role_asset"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner1) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "corner1={corner1}");
        let c1 = corner1["items"].as_array().expect("corner1 items");
        assert_eq!(c1.len(), 1);
        assert_eq!(
            c1[0]["legacy_id"].as_i64().expect("leg"),
            i64::from(asset_leg)
        );
        assert_eq!(c1[0]["asset_type"].as_str(), Some("role"));
        assert!(
            c1[0]["history_images"]
                .as_array()
                .is_some_and(|a| a.is_empty()),
            "history_images empty before app_asset_image row"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"file_path":"pg_contract/corner_hist.png","state":"已完成","sort_index":0}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, img_row) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "img_row={img_row}");
        assert_eq!(
            img_row["file_path"].as_str(),
            Some("pg_contract/corner_hist.png")
        );
        assert_eq!(img_row["state"].as_str(), Some("已完成"));

        let img_uuid = img_row["id"].as_str().expect("image id");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list_img) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "list_img={list_img}");
        assert!(
            list_img["cover_legacy_image_id"].is_null(),
            "API-created asset has no metadata.imageId cover"
        );
        let lim = list_img["items"].as_array().expect("image list items");
        assert_eq!(lim.len(), 1);
        assert_eq!(lim[0]["id"].as_str(), Some(img_uuid));
        assert_eq!(lim[0]["selected"], false);
        assert!(
            lim[0]["legacy_image_id"].is_null(),
            "API-created image has no legacy_image_id"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/assets/get-image")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"assetsId":{asset_leg}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, legacy_get_image) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "legacy_get_image={legacy_get_image}"
        );
        assert_eq!(legacy_get_image["id"].as_i64(), Some(i64::from(asset_leg)));
        assert!(legacy_get_image["imageId"].is_null());
        let legacy_temp = legacy_get_image["tempAssets"]
            .as_array()
            .expect("legacy get-image tempAssets");
        assert_eq!(legacy_temp.len(), 1);
        assert_eq!(
            legacy_temp[0]["assetsId"].as_i64(),
            Some(i64::from(asset_leg))
        );
        assert_eq!(legacy_temp[0]["selected"], false);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_uuid}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, one_img) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "one_img={one_img}");
        assert_eq!(one_img["id"].as_str(), Some(img_uuid));
        assert_eq!(
            one_img["file_path"].as_str(),
            Some("pg_contract/corner_hist.png")
        );
        assert_eq!(one_img["state"].as_str(), Some("已完成"));
        assert!(one_img["legacy_image_id"].is_null());

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"cover_legacy_image_id":424242}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, bad_cov) = read_json_response(res).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "bad_cov={bad_cov}");
        assert_eq!(bad_cov["code"].as_str(), Some("bad_request"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner1_hist) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "corner1_hist={corner1_hist}");
        let c1h = corner1_hist["items"]
            .as_array()
            .expect("corner1_hist items");
        assert_eq!(c1h.len(), 1);
        let hi = c1h[0]["history_images"].as_array().expect("history");
        assert_eq!(hi.len(), 1);
        assert_eq!(
            hi[0]["file_path"].as_str(),
            Some("pg_contract/corner_hist.png")
        );
        assert_eq!(hi[0]["state"].as_str(), Some("已完成"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_uuid}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"state":""}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, patched) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "patched={patched}");
        assert!(patched["state"].is_null());

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner_no_hist) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "corner_no_hist={corner_no_hist}");
        let cn = corner_no_hist["items"].as_array().expect("items");
        assert_eq!(cn.len(), 1);
        assert!(
            cn[0]["history_images"]
                .as_array()
                .is_some_and(|a| a.is_empty()),
            "NULL state excludes row from corner-scape history"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_uuid}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"state":"已完成"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, restored) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "restored={restored}");
        assert_eq!(restored["state"].as_str(), Some("已完成"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"name":"pg_contract_scene_asset","type":"scene"}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, scene_row) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "scene_row={scene_row}");
        let scene_leg = scene_row["legacy_id"].as_i64().expect("scene legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner2) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "corner2={corner2}");
        let c2 = corner2["items"].as_array().expect("corner2 items");
        assert_eq!(c2.len(), 2);
        assert_eq!(c2[0]["asset_type"].as_str(), Some("role"));
        assert_eq!(c2[1]["asset_type"].as_str(), Some("scene"));
        assert_eq!(c2[0]["history_images"].as_array().map(|a| a.len()), Some(1));
        assert!(
            c2[1]["history_images"]
                .as_array()
                .is_some_and(|a| a.is_empty()),
            "scene has no history row"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"types":["scene"]}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner_scene_only) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "corner_scene_only={corner_scene_only}"
        );
        let cs = corner_scene_only["items"]
            .as_array()
            .expect("corner scene filter");
        assert_eq!(cs.len(), 1);
        assert_eq!(
            cs[0]["legacy_id"].as_i64().expect("leg"),
            i64::from(scene_leg)
        );

        let n = sqlx::query(
            r#"
            UPDATE app_asset a
            SET metadata = jsonb_build_object('assetsId', 999999)
            FROM app_project p
            WHERE a.project_id = p.id
              AND p.legacy_id = $1
              AND p.owner_user_id = $2
              AND a.legacy_id = $3
            "#,
        )
        .bind(legacy_id)
        .bind(sub)
        .bind(scene_leg)
        .execute(&pool_sql)
        .await
        .expect("mark scene row as child asset via metadata.assetsId");
        assert_eq!(n.rows_affected(), 1, "expected one scene row updated");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner_child_hidden) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "corner_child_hidden={corner_child_hidden}"
        );
        let ch = corner_child_hidden["items"]
            .as_array()
            .expect("corner after child metadata");
        assert_eq!(ch.len(), 1);
        assert_eq!(
            ch[0]["legacy_id"].as_i64().expect("leg"),
            i64::from(asset_leg)
        );
        assert_eq!(ch[0]["history_images"].as_array().map(|a| a.len()), Some(1));

        let n = sqlx::query(
            r#"
            UPDATE app_asset a
            SET metadata = '{}'::jsonb
            FROM app_project p
            WHERE a.project_id = p.id
              AND p.legacy_id = $1
              AND p.owner_user_id = $2
              AND a.legacy_id = $3
            "#,
        )
        .bind(legacy_id)
        .bind(sub)
        .bind(scene_leg)
        .execute(&pool_sql)
        .await
        .expect("reset scene metadata");
        assert_eq!(n.rows_affected(), 1);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner_restored) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "corner_restored={corner_restored}");
        assert_eq!(
            corner_restored["items"].as_array().map(|a| a.len()),
            Some(2)
        );
        let cr = corner_restored["items"]
            .as_array()
            .expect("corner restored items");
        assert_eq!(cr[0]["history_images"].as_array().map(|a| a.len()), Some(1));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, stats_mid) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "stats_mid={stats_mid}");
        assert_eq!(stats_mid["script_count"], 1);
        assert_eq!(stats_mid["storyboard_count"], 0);
        assert_eq!(stats_mid["role_count"], 1);
        assert_eq!(stats_mid["novel_count"], 0);
        assert_eq!(stats_mid["video_count"], 0);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/projects/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, sum_mid) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "sum_mid={sum_mid}");
        assert_eq!(sum_mid["video_count"], 0);
        let g_role = sum_mid["role_count"].as_i64().expect("summary role_count");
        let p_role = stats_mid["role_count"].as_i64().expect("stats role_count");
        assert!(
            g_role >= p_role,
            "projects/summary role_count ({g_role}) should be >= per-project stats ({p_role})"
        );
        let g_script = sum_mid["script_count"]
            .as_i64()
            .expect("summary script_count");
        let p_script = stats_mid["script_count"]
            .as_i64()
            .expect("stats script_count");
        assert!(
            g_script >= p_script,
            "projects/summary script_count ({g_script}) should be >= per-project stats ({p_script})"
        );
        let g_asset = sum_mid["asset_count"]
            .as_i64()
            .expect("summary asset_count");
        assert!(
            g_asset >= 1,
            "expected at least one app_asset row in summary"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets?asset_type=role&name=pg_contract"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, by_type_name) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "by_type_name={by_type_name}");
        assert_eq!(by_type_name["total"], 1);
        let items = by_type_name["items"].as_array().expect("items");
        assert_eq!(items.len(), 1);
        assert_eq!(
            items[0]["legacy_id"].as_i64().expect("legacy_id"),
            i64::from(asset_leg)
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets?asset_type=tool&name=pg_contract"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, wrong_type) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "wrong_type={wrong_type}");
        assert_eq!(wrong_type["total"], 0);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets?script_legacy_id={script_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, linked_before) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "linked_before={linked_before}");
        assert_eq!(linked_before["total"], 0);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PUT)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/scripts/{script_leg}/assets/{asset_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, empty_put) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NO_CONTENT, "put body={empty_put}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets?script_legacy_id={script_leg}&limit=10&page=1"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, linked_after) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "linked_after={linked_after}");
        assert_eq!(linked_after["total"], 1);
        assert_eq!(
            linked_after["items"]
                .as_array()
                .map(|a| a.len())
                .unwrap_or(0),
            1
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/scripts/{script_leg}/assets/{asset_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, empty_unlink) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NO_CONTENT, "unlink={empty_unlink}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets?script_legacy_id={script_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, unlinked) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "unlinked={unlinked}");
        assert_eq!(unlinked["total"], 0);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/novels"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"chapter":"pg_contract_chap"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, novel_row) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "novel_row={novel_row}");
        let novel_leg = novel_row["legacy_id"].as_i64().expect("novel legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, stats_with_novel) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "stats_with_novel={stats_with_novel}"
        );
        assert_eq!(stats_with_novel["novel_count"], 1);
        assert_eq!(stats_with_novel["role_count"], 1);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/novels?search=pg_contract&page=1&limit=10"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, novel_list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "novel_list={novel_list}");
        assert!(novel_list["total"].as_i64().unwrap_or(0) >= 1);

        // Legacy POST `/api/v1/novels/*` (Electron-shaped) round-trip vs same `app_novel` rows.
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"projectId":{legacy_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, legacy_data) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "legacy_data={legacy_data}");
        let rows = legacy_data["data"].as_array().expect("legacy data array");
        assert!(
            rows.iter()
                .any(|r| { r["legacy_id"].as_i64() == Some(i64::from(novel_leg)) }),
            "expected REST novel legacy_id in get-novel-data: {legacy_data}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel-index")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"projectId":{legacy_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, legacy_idx) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "legacy_idx={legacy_idx}");
        let idx_rows = legacy_idx["data"].as_array().expect("legacy index array");
        assert!(
            idx_rows
                .iter()
                .any(|r| r["id"].as_i64() == Some(i64::from(novel_leg))),
            "expected novel_leg in get-novel-index: {legacy_idx}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel-event-state")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"ids":[{novel_leg}]}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, legacy_event_state) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "legacy_event_state={legacy_event_state}"
        );
        let event_rows = legacy_event_state["data"]
            .as_array()
            .expect("legacy event state array");
        assert!(
            event_rows.is_empty(),
            "freshly created novels should not expose non-zero event_state rows: {legacy_event_state}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{legacy_id},"page":1,"limit":10}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, get_pg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "get_novel={get_pg}");
        assert_eq!(get_pg["total"].as_i64(), Some(1));
        let page_rows = get_pg["data"].as_array().expect("get-novel data");
        assert_eq!(page_rows[0]["id"].as_i64(), Some(i64::from(novel_leg)));

        let add_body = format!(
            r#"{{"projectId":{legacy_id},"data":[{{"index":99,"reel":"lr","chapter":"pg_legacy_add_chapter","chapterData":"d0"}}]}}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/add-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(add_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, add_msg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "add_novel={add_msg}");
        assert_eq!(add_msg["message"].as_str(), Some("新增原文成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{legacy_id},"page":1,"limit":10}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, two_rows) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "two_rows={two_rows}");
        assert_eq!(two_rows["total"].as_i64(), Some(2));
        let added_leg = two_rows["data"]
            .as_array()
            .expect("data")
            .iter()
            .find(|r| r["chapter"].as_str() == Some("pg_legacy_add_chapter"))
            .expect("added chapter row")["id"]
            .as_i64()
            .expect("added legacy id") as i32;

        let upd = format!(
            r#"{{"id":{added_leg},"index":99,"reel":"","chapter":"pg_legacy_patched","chapterData":"d1","event":""}}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/update-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(upd))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, upd_msg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "update_novel={upd_msg}");
        assert_eq!(upd_msg["message"].as_str(), Some("更新原文成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{legacy_id},"page":1,"limit":10,"search":"pg_legacy_pat"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, search_pg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "search_novel={search_pg}");
        assert!(search_pg["total"].as_i64().unwrap_or(0) >= 1);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/delete-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"id":{added_leg}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, del_msg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "delete_novel={del_msg}");
        assert_eq!(del_msg["message"].as_str(), Some("删除原文成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{legacy_id},"page":1,"limit":10}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, one_again) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "one_again={one_again}");
        assert_eq!(one_again["total"].as_i64(), Some(1));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, one_novel) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "one_novel={one_novel}");
        assert_eq!(one_novel["chapter"].as_str(), Some("pg_contract_chap"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"chapter":"pg_contract_patched"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, patched_novel) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "patched={patched_novel}");
        assert_eq!(
            patched_novel["chapter"].as_str(),
            Some("pg_contract_patched")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, del_novel) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NO_CONTENT, "del_novel={del_novel}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, stats_no_novel) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "stats_no_novel={stats_no_novel}");
        assert_eq!(stats_no_novel["novel_count"], 0);
        assert_eq!(stats_no_novel["role_count"], 1);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, novel_gone) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "novel_gone={novel_gone}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, empty) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NO_CONTENT, "body={empty}");

        let res = app
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, err) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "err={err}");
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn legacy_project_crud_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let unique_suffix = Uuid::new_v4().simple().to_string();
        let initial_name = format!("pg_legacy_project_{unique_suffix}");
        let updated_name = format!("{initial_name}_updated");

        let add_body = format!(
            r#"{{
                "projectType":" short-drama ",
                "name":"  {initial_name}  ",
                "intro":"  legacy intro  ",
                "type":" novel ",
                "artStyle":"  ink  ",
                "directorManual":"  story-manual  ",
                "videoRatio":" 9:16 ",
                "imageModel":" dalle-3 ",
                "videoModel":" runway ",
                "imageQuality":" hd ",
                "mode":"   "
            }}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/project/add-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(add_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, added) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "added={added}");
        assert_eq!(added["message"].as_str(), Some("新增项目成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/project/get-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, listed) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "listed={listed}");
        let created_row = listed["data"]
            .as_array()
            .and_then(|rows| {
                rows.iter()
                    .find(|row| row["name"].as_str() == Some(initial_name.as_str()))
            })
            .cloned()
            .expect("created project row");
        let legacy_id = created_row["legacy_id"].as_i64().expect("legacy_id") as i32;
        assert_eq!(created_row["intro"].as_str(), Some("legacy intro"));
        assert_eq!(created_row["project_type"].as_str(), Some("short-drama"));
        assert_eq!(created_row["mode"].as_str(), Some("novel"));
        assert_eq!(created_row["art_style"].as_str(), Some("ink"));
        assert_eq!(
            created_row["director_manual"].as_str(),
            Some("story-manual")
        );
        assert_eq!(created_row["video_ratio"].as_str(), Some("9:16"));
        assert_eq!(created_row["image_model"].as_str(), Some("dalle-3"));
        assert_eq!(created_row["video_model"].as_str(), Some("runway"));
        assert_eq!(created_row["image_quality"].as_str(), Some("hd"));

        let stored_mode: Option<String> = sqlx::query_scalar(
            "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND legacy_id = $2",
        )
        .bind(sub)
        .bind(legacy_id)
        .fetch_optional(&pool)
        .await
        .expect("select initial mode");
        assert_eq!(stored_mode.as_deref(), Some("novel"));

        let edit_body = format!(
            r#"{{
                "id":{legacy_id},
                "name":"  {updated_name}  ",
                "intro":"   ",
                "type":"  fallback-mode  ",
                "artStyle":"   ",
                "directorManual":"  revised-manual  ",
                "videoRatio":" 16:9 ",
                "imageModel":" flux ",
                "videoModel":" kling ",
                "imageQuality":" standard ",
                "projectType":" feature ",
                "mode":" professional "
            }}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/project/edit-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(edit_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, edited) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "edited={edited}");
        assert_eq!(edited["message"].as_str(), Some("编辑项目成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/project/get-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, relisted) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "relisted={relisted}");
        let edited_row = relisted["data"]
            .as_array()
            .and_then(|rows| {
                rows.iter()
                    .find(|row| row["legacy_id"].as_i64() == Some(i64::from(legacy_id)))
            })
            .cloned()
            .expect("edited project row");
        assert_eq!(edited_row["name"].as_str(), Some(updated_name.as_str()));
        assert!(edited_row["intro"].is_null());
        assert_eq!(edited_row["project_type"].as_str(), Some("feature"));
        assert_eq!(edited_row["mode"].as_str(), Some("professional"));
        assert!(edited_row["art_style"].is_null());
        assert_eq!(
            edited_row["director_manual"].as_str(),
            Some("revised-manual")
        );
        assert_eq!(edited_row["video_ratio"].as_str(), Some("16:9"));
        assert_eq!(edited_row["image_model"].as_str(), Some("flux"));
        assert_eq!(edited_row["video_model"].as_str(), Some("kling"));
        assert_eq!(edited_row["image_quality"].as_str(), Some("standard"));

        let stored_mode: Option<String> = sqlx::query_scalar(
            "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND legacy_id = $2",
        )
        .bind(sub)
        .bind(legacy_id)
        .fetch_optional(&pool)
        .await
        .expect("select edited mode");
        assert_eq!(stored_mode.as_deref(), Some("professional"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/project/delete-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, deleted) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "deleted={deleted}");
        assert_eq!(deleted["message"].as_str(), Some("删除项目成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/project/get-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, after_delete) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "after_delete={after_delete}");
        let still_present = after_delete["data"].as_array().is_some_and(|rows| {
            rows.iter()
                .any(|row| row["legacy_id"].as_i64() == Some(i64::from(legacy_id)))
        });
        assert!(
            !still_present,
            "deleted row should be absent: {after_delete}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/project/delete-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, missing_delete) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::NOT_FOUND,
            "missing_delete={missing_delete}"
        );

        let _ = sqlx::query(
            "DELETE FROM public.app_project WHERE owner_user_id = $1 AND legacy_id = $2",
        )
        .bind(sub)
        .bind(legacy_id)
        .execute(&pool)
        .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn legacy_general_project_update_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let create_body = format!(
            r#"{{
                "name":"pg_general_project_{}",
                "intro":"before update",
                "project_type":"movie",
                "art_style":"orig-style",
                "mode":"orig-mode",
                "video_ratio":"9:16"
            }}"#,
            Uuid::new_v4().simple()
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(create_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
        let project_uuid = Uuid::parse_str(created["id"].as_str().expect("project id")).unwrap();

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/general/get-single-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, before_update) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "before_update={before_update}");
        assert_eq!(
            before_update["data"][0]["intro"].as_str(),
            Some("before update")
        );
        assert_eq!(before_update["data"][0]["mode"].as_str(), Some("orig-mode"));
        assert_eq!(
            before_update["data"][0]["art_style"].as_str(),
            Some("orig-style")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/general/update-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"id":{legacy_id},"intro":"after update","type":"legacy-mode","artStyle":null,"videoRatio":"1:1","projectType":"series"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, updated) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "updated={updated}");
        assert_eq!(updated["message"].as_str(), Some("修改成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/general/get-single-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, after_update) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "after_update={after_update}");
        assert_eq!(
            after_update["data"][0]["name"].as_str(),
            created["name"].as_str(),
            "legacy general wrapper must preserve untouched fields"
        );
        assert_eq!(
            after_update["data"][0]["intro"].as_str(),
            Some("after update")
        );
        assert_eq!(
            after_update["data"][0]["mode"].as_str(),
            Some("legacy-mode")
        );
        assert!(after_update["data"][0]["art_style"].is_null());
        assert_eq!(after_update["data"][0]["video_ratio"].as_str(), Some("1:1"));
        assert_eq!(
            after_update["data"][0]["project_type"].as_str(),
            Some("series")
        );

        let stored: (Option<String>, Option<String>, Option<String>, Option<String>) = sqlx::query_as(
            "SELECT intro, mode, art_style, project_type FROM public.app_project WHERE id = $1 AND owner_user_id = $2",
        )
        .bind(project_uuid)
        .bind(sub)
        .fetch_one(&pool)
        .await
        .expect("select updated project");
        assert_eq!(stored.0.as_deref(), Some("after update"));
        assert_eq!(stored.1.as_deref(), Some("legacy-mode"));
        assert_eq!(stored.2, None);
        assert_eq!(stored.3.as_deref(), Some("series"));

        let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
            .bind(project_uuid)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn asset_image_file_local_storage_roundtrip() {
        use base64::Engine;
        use serde_json::json;

        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let tmp = tempfile::tempdir().expect("tempdir");
        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let user_dir = tmp.path().join(sub.to_string());
        std::fs::create_dir_all(&user_dir).expect("mkdir user image dir");

        let img_id = Uuid::new_v4();
        let png = base64::engine::general_purpose::STANDARD
            .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
            .expect("1x1 png");
        std::fs::write(user_dir.join(format!("{img_id}.png")), &png).expect("write png");

        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state_with_local_dir(
            pool.clone(),
            secret.clone(),
            tmp.path().to_path_buf(),
        ));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "body={created}");
        let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"name":"pg_contract_local_png_asset","type":"role"}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, asset_row) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "asset={asset_row}");
        let asset_leg = asset_row["legacy_id"].as_i64().expect("asset legacy_id") as i32;
        let asset_id = Uuid::parse_str(asset_row["id"].as_str().expect("asset id")).unwrap();

        let api_file_path =
            format!("/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_id}/file");
        let meta = json!({"storage": "local", "source": "pg_contract"});
        sqlx::query(
            r#"
            INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
            VALUES ($1, $2, 0, $3, '已完成', $4)
            "#,
        )
        .bind(img_id)
        .bind(asset_id)
        .bind(&api_file_path)
        .bind(Json(meta))
        .execute(&pool)
        .await
        .expect("insert app_asset_image row");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_id}/file"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let cache_control = res
            .headers()
            .get(header::CACHE_CONTROL)
            .and_then(|v| v.to_str().ok())
            .map(str::to_string);
        let (status, body, ct) = read_bytes_response(res, 512 * 1024).await;
        assert_eq!(status, StatusCode::OK, "file GET");
        assert_eq!(body, png);
        assert!(
            ct.as_deref()
                .is_some_and(|s| s.to_lowercase().starts_with("image/png")),
            "content-type: {ct:?}"
        );
        assert_eq!(
            cache_control.as_deref(),
            Some("private, max-age=300"),
            "cache-control: {cache_control:?}"
        );

        let res = app
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!("/api/v1/projects/legacy/{legacy_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NO_CONTENT);
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn assets_generate_enqueue_four_kinds() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool, secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "body={created}");
        let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let gen_body = format!(
            r#"{{"projectId":{legacy_id},"model":"1:pg_ag","resolution":"1024x1024","id":1,"type":"role","name":"pg_ag_gen","prompt":"probe","base64":"QUJDRA=="}}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/assets-generate/generate")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(gen_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "generate body={job}");
        assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_IMAGE));
        assert_eq!(job["status"].as_str(), Some("queued"));
        assert_eq!(job["payload"]["has_base64"].as_bool(), Some(true));
        assert_eq!(
            job["payload"]["image_base64"].as_str(),
            Some("data:image/jpeg;base64,QUJDRA==")
        );

        let pol_body = format!(
            r#"{{"assetsId":1,"projectId":{legacy_id},"type":"role","name":"n","describe":"d"}}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/assets-generate/polish-prompt")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(pol_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "polish body={job}");
        assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_PROMPT));
        assert_eq!(job["status"].as_str(), Some("queued"));

        let bat_gen = format!(
            r#"{{"projectId":{legacy_id},"model":"1:x","resolution":"1024x1024","items":[{{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}}]}}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/assets-generate/batch-generate")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(bat_gen))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "batch-generate body={job}");
        assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_BATCH));
        assert_eq!(job["status"].as_str(), Some("queued"));
        assert_eq!(
            job["payload"]["items"][0]["has_base64"].as_bool(),
            Some(true)
        );
        assert_eq!(
            job["payload"]["items"][0]["image_base64"].as_str(),
            Some("data:image/png;base64,AA==")
        );

        let bat_pol = format!(
            r#"{{"projectId":{legacy_id},"items":[{{"assetsId":1,"type":"role","name":"n","describe":"d"}}]}}"#
        );
        let res = app
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/assets-generate/batch-polish")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(bat_pol))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "batch-polish body={job}");
        assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_BATCH));
        assert_eq!(job["status"].as_str(), Some("queued"));
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn settings_vendor_model_test_enqueue() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool, secret));

        let body = r#"{"modelName":"pg_vendor_mt","type":"text","id":"probe-id"}"#;
        let res = app
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/model-test")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "model-test body={job}");
        assert_eq!(
            job["kind"].as_str(),
            Some(JOB_KIND_SETTINGS_VENDOR_MODEL_TEST)
        );
        assert_eq!(job["status"].as_str(), Some("queued"));
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn quality_reviews_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let quality_job_id = Uuid::new_v4();
        let script_target_id = format!("pg_quality_script_{}", Uuid::new_v4());
        let asset_target_id = format!("pg_quality_asset_{}", Uuid::new_v4());
        let mut created_review_ids = Vec::new();
        let mut created_job_ids = Vec::new();
        let script_review_id_text;
        let asset_review_id_text;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .header("Idempotency-Key", format!("quality-review-{quality_job_id}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"kind":"flutter.probe","payload":{{"scope":"quality-review","marker":"{quality_job_id}"}}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "created_job={created_job}");
        let quality_job_id = Uuid::parse_str(created_job["id"].as_str().expect("quality job id"))
            .expect("quality job uuid");
        created_job_ids.push(quality_job_id);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/quality/reviews")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"targetType":"script","targetId":"{script_target_id}","jobId":"{quality_job_id}","source":"auto","overallScore":8,"passed":true,"comments":"pg quality script"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created_script) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "script review={created_script}");
        assert_eq!(created_script["targetType"], "script");
        assert_eq!(
            created_script["targetId"].as_str(),
            Some(script_target_id.as_str())
        );
        assert_eq!(created_script["source"], "auto");
        assert_eq!(created_script["overallScore"], 8);
        assert_eq!(created_script["passed"], true);
        let script_review_id =
            Uuid::parse_str(created_script["id"].as_str().expect("script review id")).unwrap();
        script_review_id_text = script_review_id.to_string();
        created_review_ids.push(script_review_id);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/quality/reviews")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"targetType":"asset","targetId":"{asset_target_id}","jobId":"{quality_job_id}","overallScore":4,"passed":false,"isBadCase":true,"badCaseCategory":"visual_error","comments":"pg quality asset"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created_asset) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "asset review={created_asset}");
        assert_eq!(created_asset["targetType"], "asset");
        assert_eq!(
            created_asset["targetId"].as_str(),
            Some(asset_target_id.as_str())
        );
        assert_eq!(created_asset["source"], "manual");
        assert_eq!(created_asset["isBadCase"], true);
        assert_eq!(created_asset["badCaseCategory"], "visual_error");
        let asset_review_id =
            Uuid::parse_str(created_asset["id"].as_str().expect("asset review id")).unwrap();
        asset_review_id_text = asset_review_id.to_string();
        created_review_ids.push(asset_review_id);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/quality/reviews?targetType=script&targetId={script_target_id}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, filtered) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "filtered={filtered}");
        let filtered = filtered.as_array().expect("filtered list");
        assert_eq!(filtered.len(), 1);
        assert_eq!(
            filtered[0]["id"].as_str(),
            Some(script_review_id_text.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/quality/reviews?isBadCase=true")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, bad_cases) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "bad_cases={bad_cases}");
        let bad_cases = bad_cases.as_array().expect("bad cases list");
        assert!(
            bad_cases
                .iter()
                .any(|row| row["id"].as_str() == Some(asset_review_id_text.as_str())),
            "bad case list should include created asset review: {bad_cases:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/quality/reviews?jobId={quality_job_id}&limit=1&offset=0"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, job_page_one) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "job_page_one={job_page_one}");
        let job_page_one = job_page_one.as_array().expect("job page one");
        assert_eq!(job_page_one.len(), 1);
        assert_eq!(
            job_page_one[0]["id"].as_str(),
            Some(asset_review_id_text.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/quality/reviews?jobId={quality_job_id}&limit=1&offset=1"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, job_page_two) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "job_page_two={job_page_two}");
        let job_page_two = job_page_two.as_array().expect("job page two");
        assert_eq!(job_page_two.len(), 1);
        assert_eq!(
            job_page_two[0]["id"].as_str(),
            Some(script_review_id_text.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/quality/reviews?jobId={quality_job_id}&targetType=asset&isBadCase=true"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, combined_filters) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "combined_filters={combined_filters}"
        );
        let combined_filters = combined_filters.as_array().expect("combined filter rows");
        assert_eq!(combined_filters.len(), 1);
        assert_eq!(
            combined_filters[0]["id"].as_str(),
            Some(asset_review_id_text.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/quality/reviews?targetId={script_target_id}&limit=1&offset=0"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, target_id_only) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "target_id_only={target_id_only}");
        let target_id_only = target_id_only.as_array().expect("target id only rows");
        assert_eq!(target_id_only.len(), 1);
        assert_eq!(
            target_id_only[0]["id"].as_str(),
            Some(script_review_id_text.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/quality/reviews/{script_review_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, review_by_id) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "review_by_id={review_by_id}");
        assert_eq!(
            review_by_id["targetId"].as_str(),
            Some(script_target_id.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/quality/stats")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, stats) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "stats={stats}");
        let stats = stats.as_array().expect("stats list");
        let script_stats = stats
            .iter()
            .find(|row| row["targetType"].as_str() == Some("script"))
            .expect("script stats row");
        assert!(
            script_stats["totalReviews"].as_i64().unwrap_or_default() >= 1,
            "script stats={script_stats}"
        );
        assert!(
            script_stats["passedCount"].as_i64().unwrap_or_default() >= 1,
            "script stats={script_stats}"
        );
        let asset_stats = stats
            .iter()
            .find(|row| row["targetType"].as_str() == Some("asset"))
            .expect("asset stats row");
        assert!(
            asset_stats["badCaseCount"].as_i64().unwrap_or_default() >= 1,
            "asset stats={asset_stats}"
        );
        assert!(
            asset_stats["failedCount"].as_i64().unwrap_or_default() >= 1,
            "asset stats={asset_stats}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/quality/stage-pass-rate")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, stage_rows) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "stage_rows={stage_rows}");
        let stage_rows = stage_rows.as_array().expect("stage pass rate list");
        assert!(
            stage_rows.iter().any(|row| {
                row["targetType"].as_str() == Some("script")
                    && row["passedCount"].as_i64().unwrap_or_default() >= 1
            }),
            "stage rows should include script aggregate: {stage_rows:?}"
        );
        assert!(
            stage_rows.iter().any(|row| {
                row["targetType"].as_str() == Some("asset")
                    && row["badCaseCount"].as_i64().unwrap_or_default() >= 1
            }),
            "stage rows should include asset aggregate: {stage_rows:?}"
        );

        cleanup_quality_reviews(&pool, &created_review_ids).await;
        cleanup_jobs(&pool, &created_job_ids).await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn tasks_legacy_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let project_name = format!("pg_task_center_{}", Uuid::new_v4());
        let idem_key = format!("pg-task-idem-{}", Uuid::new_v4());
        let mut created_job_ids = Vec::new();

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"name":"{project_name}"}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created_project) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "project={created_project}");
        let legacy_project_id = created_project["legacy_id"]
            .as_i64()
            .expect("legacy project id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .header("Idempotency-Key", idem_key.as_str())
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"kind":"flutter.probe","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"idem"}}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "created_job={created_job}");
        let created_job_id =
            Uuid::parse_str(created_job["id"].as_str().expect("created job id")).unwrap();
        created_job_ids.push(created_job_id);
        assert_eq!(
            created_job["idempotency_key"].as_str(),
            Some(idem_key.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .header("Idempotency-Key", idem_key.as_str())
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"kind":"flutter.probe","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"idem-retry"}}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, idem_retry) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "idem_retry={idem_retry}");
        assert_eq!(idem_retry["id"], created_job["id"]);
        assert_eq!(idem_retry["payload"]["marker"], "idem");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"kind":"{JOB_KIND_ASSET_GENERATE_IMAGE}","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"failed"}}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, failed_seed_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "failed_seed_job={failed_seed_job}");
        let failed_seed_job_id =
            Uuid::parse_str(failed_seed_job["id"].as_str().expect("failed seed job id")).unwrap();
        created_job_ids.push(failed_seed_job_id);

        sqlx::query(
            "UPDATE public.app_generation_job SET status = 'failed', error_message = 'pg task center failure' WHERE id = $1",
        )
        .bind(failed_seed_job_id)
        .execute(&pool)
        .await
        .expect("mark failed seed job");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/tasks/get-project")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, task_projects) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "task_projects={task_projects}");
        let task_projects = task_projects["data"].as_array().expect("task project rows");
        assert!(
            task_projects.iter().any(|row| {
                row["id"].as_i64() == Some(i64::from(legacy_project_id))
                    && row["name"].as_str() == Some(project_name.as_str())
            }),
            "task center project list should include created project: {task_projects:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/tasks/get-task-categories")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, task_categories) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "task_categories={task_categories}");
        let task_categories = task_categories["data"]
            .as_array()
            .expect("task category rows");
        assert!(
            task_categories
                .iter()
                .any(|row| row["taskClass"].as_str() == Some("flutter.probe")),
            "task categories should include flutter.probe: {task_categories:?}"
        );
        assert!(
            task_categories
                .iter()
                .any(|row| row["taskClass"].as_str() == Some(JOB_KIND_ASSET_GENERATE_IMAGE)),
            "task categories should include asset generate: {task_categories:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/tasks/get-task-api")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"page":1,"limit":10,"projectId":{legacy_project_id},"taskClass":"flutter.probe","state":"queued"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, filtered_jobs) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "filtered_jobs={filtered_jobs}");
        assert_eq!(filtered_jobs["total"].as_i64(), Some(1));
        let filtered_jobs = filtered_jobs["data"]
            .as_array()
            .expect("filtered task rows");
        assert_eq!(filtered_jobs.len(), 1);
        assert_eq!(filtered_jobs[0]["id"], created_job["id"]);
        assert_eq!(filtered_jobs[0]["status"], "queued");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/tasks/get-task-api")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"page":1,"limit":10,"projectId":{legacy_project_id},"state":"failed"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, failed_jobs) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "failed_jobs={failed_jobs}");
        assert_eq!(failed_jobs["total"].as_i64(), Some(1));
        let failed_jobs = failed_jobs["data"].as_array().expect("failed task rows");
        assert_eq!(failed_jobs.len(), 1);
        assert_eq!(failed_jobs[0]["id"], failed_seed_job["id"]);
        assert_eq!(failed_jobs[0]["status"], "failed");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/tasks/task-details")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"taskId":"{created_job_id}"}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, task_detail) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "task_detail={task_detail}");
        assert_eq!(task_detail["id"], created_job["id"]);
        assert_eq!(task_detail["legacy_task_id"], created_job["legacy_task_id"]);
        let legacy_project_id_text = legacy_project_id.to_string();
        assert_eq!(
            task_detail["payload"]["project_legacy_id"].as_str(),
            Some(legacy_project_id_text.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/tasks/task-details")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"taskId":{}}}"#,
                        created_job["legacy_task_id"]
                            .as_i64()
                            .expect("legacy task id")
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, task_detail_by_int) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "task_detail_by_int={task_detail_by_int}"
        );
        assert_eq!(task_detail_by_int["id"], created_job["id"]);
        assert_eq!(
            task_detail_by_int["legacy_task_id"],
            created_job["legacy_task_id"]
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/tasks/task-details")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"taskId":"{}"}}"#,
                        created_job["legacy_task_id"]
                            .as_i64()
                            .expect("legacy task id")
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, task_detail_by_numeric_string) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "task_detail_by_numeric_string={task_detail_by_numeric_string}"
        );
        assert_eq!(task_detail_by_numeric_string["id"], created_job["id"]);

        cleanup_jobs(&pool, &created_job_ids).await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(legacy_project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn jobs_rest_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let mut created_job_ids = Vec::new();
        let cancel_job_id_text;
        let retry_job_id_text;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"kind":"flutter.probe","payload":{"probe":"jobs-rest","slot":"cancel"}}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, cancel_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "cancel_job={cancel_job}");
        let cancel_job_id =
            Uuid::parse_str(cancel_job["id"].as_str().expect("cancel job id")).unwrap();
        cancel_job_id_text = cancel_job_id.to_string();
        created_job_ids.push(cancel_job_id);
        assert_eq!(cancel_job["kind"], "flutter.probe");
        assert_eq!(cancel_job["status"], "queued");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"probe":"jobs-rest","slot":"retry"}}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, retry_job_seed) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "retry_job_seed={retry_job_seed}");
        let retry_job_id =
            Uuid::parse_str(retry_job_seed["id"].as_str().expect("retry job id")).unwrap();
        retry_job_id_text = retry_job_id.to_string();
        created_job_ids.push(retry_job_id);
        assert_eq!(retry_job_seed["kind"], JOB_KIND_ASSET_POLISH_PROMPT);
        assert_eq!(retry_job_seed["status"], "queued");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, jobs_before_cancel) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "jobs_before_cancel={jobs_before_cancel}"
        );
        let jobs_before_cancel = jobs_before_cancel.as_array().expect("jobs list");
        assert!(
            jobs_before_cancel
                .iter()
                .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
            "jobs list should include cancel job: {jobs_before_cancel:?}"
        );
        assert!(
            jobs_before_cancel
                .iter()
                .any(|row| row["id"].as_str() == Some(retry_job_id_text.as_str())),
            "jobs list should include retry job: {jobs_before_cancel:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/jobs?kind=flutter.probe&status=queued")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, filtered_queued) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "filtered_queued={filtered_queued}");
        let filtered_queued = filtered_queued.as_array().expect("filtered queued rows");
        assert!(
            filtered_queued
                .iter()
                .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
            "queued flutter jobs should include cancel target: {filtered_queued:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/jobs/kinds")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, kinds) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "kinds={kinds}");
        let kinds = kinds.as_array().expect("job kinds");
        assert!(
            kinds
                .iter()
                .any(|row| row.as_str() == Some("flutter.probe")),
            "job kinds should include flutter.probe: {kinds:?}"
        );
        assert!(
            kinds
                .iter()
                .any(|row| row.as_str() == Some(JOB_KIND_ASSET_POLISH_PROMPT)),
            "job kinds should include asset polish: {kinds:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/jobs/kinds/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, kind_summary) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "kind_summary={kind_summary}");
        let kind_summary = kind_summary.as_array().expect("job kind summaries");
        assert!(
            kind_summary.iter().any(|row| {
                row["kind"].as_str() == Some("flutter.probe")
                    && row["job_count"].as_i64().unwrap_or_default() >= 1
            }),
            "kind summary should include flutter.probe: {kind_summary:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/jobs/status/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, status_summary_before_cancel) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "status_summary_before_cancel={status_summary_before_cancel}"
        );
        let status_summary_before_cancel = status_summary_before_cancel
            .as_array()
            .expect("job status summaries");
        assert!(
            status_summary_before_cancel.iter().any(|row| {
                row["status"].as_str() == Some("queued")
                    && row["job_count"].as_i64().unwrap_or_default() >= 2
            }),
            "status summary should include queued jobs: {status_summary_before_cancel:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/jobs/{cancel_job_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, fetched_cancel_job) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "fetched_cancel_job={fetched_cancel_job}"
        );
        assert_eq!(fetched_cancel_job["id"], cancel_job["id"]);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/jobs/{cancel_job_id}/cancel"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, cancelled_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "cancelled_job={cancelled_job}");
        assert_eq!(cancelled_job["status"], "cancelled");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/jobs?status=cancelled")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, cancelled_list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "cancelled_list={cancelled_list}");
        let cancelled_list = cancelled_list.as_array().expect("cancelled job rows");
        assert!(
            cancelled_list
                .iter()
                .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
            "cancelled filter should include cancelled job: {cancelled_list:?}"
        );

        sqlx::query(
            "UPDATE public.app_generation_job SET status = 'failed', error_message = 'pg jobs retry failure', result = '{\"ok\":false}'::jsonb WHERE id = $1",
        )
        .bind(retry_job_id)
        .execute(&pool)
        .await
        .expect("mark retry seed failed");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/jobs/{retry_job_id}/retry"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, retried_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "retried_job={retried_job}");
        assert_eq!(retried_job["status"], "queued");
        assert!(retried_job["error_message"].is_null());
        assert!(retried_job["result"].is_null());

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/usage/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, usage_summary) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "usage_summary={usage_summary}");
        assert!(
            usage_summary["eventsLast24h"].as_i64().unwrap_or_default() >= 2,
            "usage summary should see created job events: {usage_summary}"
        );
        assert!(
            usage_summary["eventCountsLast7d"]["generation_job.created"]
                .as_i64()
                .unwrap_or_default()
                >= 2,
            "usage summary should include generation_job.created count: {usage_summary}"
        );

        cleanup_jobs(&pool, &created_job_ids).await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn billing_webhook_events_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let base = Uuid::new_v4().simple().to_string();
        let stripe_info_id = format!("stripe:evt_pg_{base}_info");
        let stripe_failed_id = format!("stripe:evt_pg_{base}_failed");
        let alipay_info_id = format!("alipay:evt_pg_{base}_ali");
        let stripe_info_raw_id = format!("evt_pg_{base}_info");
        let stripe_failed_raw_id = format!("evt_pg_{base}_failed");
        let alipay_raw_id = format!("evt_pg_{base}_ali");
        let created_ids = vec![
            stripe_info_id.clone(),
            stripe_failed_id.clone(),
            alipay_info_id.clone(),
        ];

        cleanup_billing_webhook_events(&pool, &created_ids).await;

        let stripe_info_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:00:00Z")
            .unwrap()
            .with_timezone(&chrono::Utc);
        let stripe_failed_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:10:00Z")
            .unwrap()
            .with_timezone(&chrono::Utc);
        let alipay_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:20:00Z")
            .unwrap()
            .with_timezone(&chrono::Utc);

        let stripe_info_row: (i64,) = sqlx::query_as(
            r#"
            INSERT INTO public.app_billing_webhook_event (
                provider_event_id,
                payload,
                created_at,
                provider,
                raw_event_id,
                event_type,
                event_created_at,
                is_informational_event
            ) VALUES ($1, '{}'::jsonb, $2, 'stripe', $3, 'invoice.upcoming', $4, true)
            RETURNING id
            "#,
        )
        .bind(&stripe_info_id)
        .bind(stripe_info_created)
        .bind(&stripe_info_raw_id)
        .bind(stripe_info_created)
        .fetch_one(&pool)
        .await
        .expect("insert stripe informational webhook row");

        let stripe_failed_row: (i64,) = sqlx::query_as(
            r#"
            INSERT INTO public.app_billing_webhook_event (
                provider_event_id,
                payload,
                created_at,
                provider,
                raw_event_id,
                event_type,
                event_created_at,
                is_informational_event
            ) VALUES ($1, '{}'::jsonb, $2, 'stripe', $3, 'invoice.payment_failed', $4, false)
            RETURNING id
            "#,
        )
        .bind(&stripe_failed_id)
        .bind(stripe_failed_created)
        .bind(&stripe_failed_raw_id)
        .bind(stripe_failed_created)
        .fetch_one(&pool)
        .await
        .expect("insert stripe failed webhook row");

        let _: (i64,) = sqlx::query_as(
            r#"
            INSERT INTO public.app_billing_webhook_event (
                provider_event_id,
                payload,
                created_at,
                provider,
                raw_event_id,
                event_type,
                event_created_at,
                is_informational_event
            ) VALUES ($1, '{}'::jsonb, $2, 'alipay', $3, 'trade.finished', $4, true)
            RETURNING id
            "#,
        )
        .bind(&alipay_info_id)
        .bind(alipay_created)
        .bind(&alipay_raw_id)
        .bind(alipay_created)
        .fetch_one(&pool)
        .await
        .expect("insert alipay webhook row");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/webhooks/billing/events?informational_event=true&provider=stripe&raw_event_id_prefix=evt_pg_{base}_&event_type=invoice.upcoming&provider_event_id={stripe_info_id}&provider_event_id_prefix=stripe:evt_pg_{base}_&event_created_from=2026-04-08T11:59:00Z&event_created_to=2026-04-08T12:01:00Z&created_from=2026-04-08T11:59:00Z&created_to=2026-04-08T12:01:00Z&id_min={}&id_max={}&sort=id_asc&limit=10&offset=0",
                        stripe_info_row.0,
                        stripe_info_row.0
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, filtered) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "filtered={filtered}");
        assert_eq!(filtered["total"].as_i64(), Some(1));
        assert_eq!(filtered["has_more"], false);
        assert!(filtered["next_offset"].is_null());
        let filtered_items = filtered["items"].as_array().expect("filtered items");
        assert_eq!(filtered_items.len(), 1);
        assert_eq!(
            filtered_items[0]["provider_event_id"].as_str(),
            Some(stripe_info_id.as_str())
        );
        assert_eq!(filtered_items[0]["provider"].as_str(), Some("stripe"));
        assert_eq!(
            filtered_items[0]["raw_event_id"].as_str(),
            Some(stripe_info_raw_id.as_str())
        );
        assert_eq!(
            filtered_items[0]["event_type"].as_str(),
            Some("invoice.upcoming")
        );
        assert_eq!(filtered_items[0]["is_informational_event"], true);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/webhooks/billing/events?provider=stripe&sort=id_desc&limit=1&offset=0")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, paged) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "paged={paged}");
        assert_eq!(paged["total"].as_i64(), Some(2));
        assert_eq!(paged["limit"].as_i64(), Some(1));
        assert_eq!(paged["offset"].as_i64(), Some(0));
        assert_eq!(paged["has_more"], true);
        assert_eq!(paged["next_offset"].as_i64(), Some(1));
        let paged_items = paged["items"].as_array().expect("paged items");
        assert_eq!(paged_items.len(), 1);
        assert_eq!(
            paged_items[0]["provider_event_id"].as_str(),
            Some(stripe_failed_id.as_str())
        );
        assert_eq!(paged_items[0]["id"].as_i64(), Some(stripe_failed_row.0));

        cleanup_billing_webhook_events(&pool, &created_ids).await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn promote_staging_populates_assets_and_links() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(3)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        cleanup_promote_staging_fixtures(&pool).await;

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        sqlx::query(
            r#"INSERT INTO public.legacy_user_map (legacy_user_id, supabase_user_id)
               VALUES ($1, $2)
               ON CONFLICT (legacy_user_id) DO UPDATE SET supabase_user_id = EXCLUDED.supabase_user_id"#,
        )
        .bind(PROMO_LEGACY_USER)
        .bind(sub)
        .execute(&pool)
        .await
        .expect("legacy_user_map insert (requires existing auth.users id = CONTRACT_USER_SUB)");

        let project = serde_json::json!({
            "id": PROMO_PROJECT_LEG,
            "userId": PROMO_LEGACY_USER,
            "name": "pg_promote_project",
        });
        sqlx::query(
            r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
               VALUES ('o_project', 'pg_promote_proj', $1)"#,
        )
        .bind(Json(project))
        .execute(&pool)
        .await
        .expect("staging o_project");

        let script = serde_json::json!({
            "id": PROMO_SCRIPT_LEG,
            "projectId": PROMO_PROJECT_LEG,
            "name": "pg_promote_script",
        });
        sqlx::query(
            r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
               VALUES ('o_script', 'pg_promote_script', $1)"#,
        )
        .bind(Json(script))
        .execute(&pool)
        .await
        .expect("staging o_script");

        let asset = serde_json::json!({
            "id": PROMO_ASSET_LEG,
            "projectId": PROMO_PROJECT_LEG,
            "name": "pg_promote_hero",
            "type": "character",
            "describe": "promoted lead",
            "imageId": PROMO_IMAGE_LEG,
        });
        sqlx::query(
            r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
               VALUES ('o_assets', 'pg_promote_asset', $1)"#,
        )
        .bind(Json(asset))
        .execute(&pool)
        .await
        .expect("staging o_assets");

        let link = serde_json::json!({
            "scriptId": PROMO_SCRIPT_LEG,
            "assetId": PROMO_ASSET_LEG,
        });
        sqlx::query(
            r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
               VALUES ('o_scriptAssets', 'pg_promote_script_asset', $1)"#,
        )
        .bind(Json(link))
        .execute(&pool)
        .await
        .expect("staging o_scriptAssets");

        let art_style = serde_json::json!({
            "id": PROMO_ART_STYLE_LEG,
            "name": "pg_promote_style",
            "fileUrl": "/art/promo.jpg",
            "label": "pg_label",
            "prompt": "pg_prompt",
        });
        sqlx::query(
            r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
               VALUES ('o_artStyle', 'pg_promote_art_style', $1)"#,
        )
        .bind(Json(art_style))
        .execute(&pool)
        .await
        .expect("staging o_artStyle");

        let o_prompt_row = serde_json::json!({
            "id": 1,
            "name": "事件提取",
            "type": "eventExtraction",
            "data": "pg_promoted_prompt_body_evt",
        });
        sqlx::query(
            r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
               VALUES ('o_prompt', 'pg_promote_prompt', $1)"#,
        )
        .bind(Json(o_prompt_row))
        .execute(&pool)
        .await
        .expect("staging o_prompt");

        let o_image_row = serde_json::json!({
            "id": PROMO_IMAGE_LEG,
            "assetsId": PROMO_ASSET_LEG,
            "filePath": "/promo/history_corner.png",
            "state": "已完成",
        });
        sqlx::query(
            r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
               VALUES ('o_image', 'pg_promote_image', $1)"#,
        )
        .bind(Json(o_image_row))
        .execute(&pool)
        .await
        .expect("staging o_image");

        sqlx::query("SELECT 1 FROM public.promote_legacy_from_staging() LIMIT 1")
            .execute(&pool)
            .await
            .expect("promote_legacy_from_staging");

        let asset_rows: i64 = sqlx::query_scalar(
            "SELECT COUNT(*)::bigint FROM public.app_asset WHERE legacy_id = $1",
        )
        .bind(PROMO_ASSET_LEG)
        .fetch_one(&pool)
        .await
        .expect("count app_asset");
        assert_eq!(asset_rows, 1, "expected one promoted app_asset row");

        let link_rows: i64 = sqlx::query_scalar(
            r#"SELECT COUNT(*)::bigint FROM public.app_script_asset sa
               INNER JOIN public.app_script sc ON sc.id = sa.script_id
               INNER JOIN public.app_asset a ON a.id = sa.asset_id
               WHERE sc.legacy_id = $1 AND a.legacy_id = $2"#,
        )
        .bind(PROMO_SCRIPT_LEG)
        .bind(PROMO_ASSET_LEG)
        .fetch_one(&pool)
        .await
        .expect("count script_asset link");
        assert_eq!(link_rows, 1, "expected one promoted app_script_asset row");

        let promoted_img: i64 = sqlx::query_scalar(
            "SELECT COUNT(*)::bigint FROM public.app_asset_image WHERE legacy_image_id = $1",
        )
        .bind(PROMO_IMAGE_LEG)
        .fetch_one(&pool)
        .await
        .expect("count app_asset_image by legacy_image_id");
        assert_eq!(promoted_img, 1, "expected one promoted app_asset_image row");

        let style_rows: i64 = sqlx::query_scalar(
            "SELECT COUNT(*)::bigint FROM public.app_art_style WHERE legacy_id = $1",
        )
        .bind(PROMO_ART_STYLE_LEG)
        .fetch_one(&pool)
        .await
        .expect("count app_art_style");
        assert_eq!(style_rows, 1, "expected one promoted app_art_style row");

        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/art-styles")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, styles_body) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "art_styles={styles_body}");
        let sitems = styles_body["items"].as_array().expect("style items");
        let sfound = sitems
            .iter()
            .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ART_STYLE_LEG)));
        let srow = sfound.expect("promoted art style in list");
        assert_eq!(srow["name"].as_str(), Some("pg_promote_style"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets",
                        PROMO_PROJECT_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "assets list={list}");
        let items = list["items"].as_array().expect("items");
        let found = items
            .iter()
            .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)));
        let row = found.expect("promoted asset in list");
        assert_eq!(row["name"].as_str(), Some("pg_promote_hero"));
        assert_eq!(row["asset_type"].as_str(), Some("role"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets?script_legacy_id={}",
                        PROMO_PROJECT_LEG, PROMO_SCRIPT_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, linked) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "linked={linked}");
        assert_eq!(linked["total"], 1);
        assert_eq!(
            linked["items"][0]["legacy_id"].as_i64(),
            Some(i64::from(PROMO_ASSET_LEG))
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets/corner-scape",
                        PROMO_PROJECT_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, corner) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "corner={corner}");
        let citems = corner["items"].as_array().expect("corner items");
        let hero = citems
            .iter()
            .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)))
            .expect("promoted asset in corner-scape");
        let hist = hero["history_images"].as_array().expect("history_images");
        assert_eq!(hist.len(), 1);
        assert_eq!(
            hist[0]["file_path"].as_str(),
            Some("/promo/history_corner.png")
        );
        assert_eq!(hist[0]["state"].as_str(), Some("已完成"));
        assert_eq!(
            hist[0]["legacy_image_id"].as_i64(),
            Some(i64::from(PROMO_IMAGE_LEG))
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets/{}/images",
                        PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, promo_list_img) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "promo_list_img={promo_list_img}");
        assert_eq!(
            promo_list_img["cover_legacy_image_id"].as_i64(),
            Some(i64::from(PROMO_IMAGE_LEG))
        );
        let plim = promo_list_img["items"]
            .as_array()
            .expect("promoted image list items");
        assert_eq!(plim.len(), 1);
        assert_eq!(plim[0]["selected"], true);
        assert_eq!(
            plim[0]["legacy_image_id"].as_i64(),
            Some(i64::from(PROMO_IMAGE_LEG))
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets/{}",
                        PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"cover_legacy_image_id":null}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "clear cover via PATCH");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets/{}/images",
                        PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, cleared_list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "cleared_list={cleared_list}");
        assert!(cleared_list["cover_legacy_image_id"].is_null());
        let clim = cleared_list["items"].as_array().expect("cleared items");
        assert_eq!(clim[0]["selected"], false);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets/{}",
                        PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"cover_legacy_image_id":{}}}"#,
                        PROMO_IMAGE_LEG
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "restore cover via PATCH");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/assets/{}/images",
                        PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, restored_list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "restored_list={restored_list}");
        assert_eq!(
            restored_list["cover_legacy_image_id"].as_i64(),
            Some(i64::from(PROMO_IMAGE_LEG))
        );
        let rlim = restored_list["items"].as_array().expect("restored items");
        assert_eq!(rlim[0]["selected"], true);

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, prompts_body) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "prompts={prompts_body}");
        let parr = prompts_body.as_array().expect("prompts json array");
        assert_eq!(parr.len(), 3);
        let p1 = parr
            .iter()
            .find(|row| row["id"].as_i64() == Some(1))
            .expect("prompt legacy id 1");
        assert_eq!(
            p1["data"].as_str(),
            Some("pg_promoted_prompt_body_evt"),
            "promoted o_prompt body should override file default"
        );

        cleanup_promote_staging_fixtures(&pool).await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn prompts_list_patch_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
            .bind(sub)
            .execute(&pool)
            .await
            .expect("cleanup app_user_prompt");

        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "list={list}");
        let arr = list.as_array().expect("prompts array");
        assert_eq!(arr.len(), 3);

        let patch_body = r#"{"data":"pg_contract_prompt_patch_slot_2"}"#;
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri("/api/v1/prompts/2")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(patch_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, patched) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "patched={patched}");
        assert_eq!(
            patched["data"].as_str(),
            Some("pg_contract_prompt_patch_slot_2")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts/2")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, one) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "get one={one}");
        assert_eq!(one["id"].as_i64(), Some(2));
        assert_eq!(
            one["data"].as_str(),
            Some("pg_contract_prompt_patch_slot_2")
        );

        let res = app
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, again) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "again={again}");
        let p2 = again
            .as_array()
            .expect("array")
            .iter()
            .find(|row| row["id"].as_i64() == Some(2))
            .expect("id 2");
        assert_eq!(p2["data"].as_str(), Some("pg_contract_prompt_patch_slot_2"));

        let _ = sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
            .bind(sub)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn art_styles_crud_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/art-styles")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"name":"pg_contract_art_style","prompt":"pg_contract_prompt"}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let leg = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/art-styles")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "list={list}");
        assert!(list["total"].as_i64().unwrap_or(0) >= 1);
        let items = list["items"].as_array().expect("items");
        assert!(items
            .iter()
            .any(|row| row["legacy_id"].as_i64() == Some(i64::from(leg))));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, one) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "one={one}");
        assert_eq!(one["name"].as_str(), Some("pg_contract_art_style"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"label":"pg_contract_label"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, patched) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "patched={patched}");
        assert_eq!(patched["label"].as_str(), Some("pg_contract_label"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(res.status(), StatusCode::NO_CONTENT);

        let res = app
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, gone) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "gone={gone}");
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn art_styles_base64_cover_roundtrip() {
        use serde_json::json;

        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let tmp = tempfile::tempdir().expect("tempdir");
        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state_with_local_art_style_dir(
            pool.clone(),
            secret.clone(),
            tmp.path().to_path_buf(),
        ));

        let cover =
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/art-styles")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        json!({
                            "name": "pg_contract_art_style_cover",
                            "file_url": cover,
                            "prompt": "cover prompt"
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
        let cover_uri = format!("/api/v1/art-styles/legacy/{legacy_id}/cover");
        assert_eq!(created["file_url"].as_str(), Some(cover_uri.as_str()));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(&cover_uri)
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, bytes, ct) = read_bytes_response(res, 64 * 1024).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(ct.as_deref(), Some("image/png"));
        assert!(!bytes.is_empty(), "cover bytes should be non-empty");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!("/api/v1/art-styles/legacy/{legacy_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"file_url":null}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, patched) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "patched={patched}");
        assert!(patched["file_url"].is_null());

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(&cover_uri)
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, missing) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "missing={missing}");

        let _ = sqlx::query("DELETE FROM public.app_art_style WHERE owner_user_id = $1")
            .bind(sub)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn vendor_config_enable_update_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        // Get vendors summary (initially no user config)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/vendors/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, summary) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "summary={summary}");
        assert_eq!(
            summary["source"].as_str(),
            Some("static_catalog_with_user_config")
        );
        let vendors = summary["vendors"].as_array().expect("vendors array");
        assert!(!vendors.is_empty());
        let first_vendor_id = vendors[0]["id"].as_i64().expect("vendor id") as i32;
        let first_vendor_id_str = format!("{}", first_vendor_id);

        // Initially no userConfig present
        assert!(vendors[0]["userConfig"].is_null() || vendors[0]["userConfig"].is_object());

        // Enable vendor
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/enable")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"id":"{}","enable":1}}"#,
                        first_vendor_id_str
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, enabled) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "enabled={enabled}");
        assert_eq!(
            enabled["vendorId"].as_str(),
            Some(first_vendor_id_str.as_str())
        );
        assert_eq!(enabled["enabled"].as_bool(), Some(true));

        // Verify summary shows enabled vendor with userConfig
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/vendors/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, summary2) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "summary2={summary2}");
        let vendors2 = summary2["vendors"].as_array().expect("vendors array");
        let v0 = vendors2
            .iter()
            .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
            .expect("vendor in summary2");
        assert_eq!(
            v0["userConfig"]["vendorId"].as_str(),
            Some(first_vendor_id_str.as_str())
        );
        assert_eq!(v0["userConfig"]["enabled"].as_bool(), Some(true));

        // Update vendor with display name and model selection
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/update")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"id":"{}","displayName":"My Vendor","selectedModels":["gpt-4o-mini"],"settings":{{"timeout":"30"}}}}"#,
                        first_vendor_id_str
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, updated) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "updated={updated}");
        assert_eq!(
            updated["vendorId"].as_str(),
            Some(first_vendor_id_str.as_str())
        );

        // Verify summary shows updated config
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/vendors/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, summary3) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "summary3={summary3}");
        let vendors3 = summary3["vendors"].as_array().expect("vendors array");
        let v0_3 = vendors3
            .iter()
            .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
            .expect("vendor");
        assert_eq!(
            v0_3["userConfig"]["displayName"].as_str(),
            Some("My Vendor")
        );
        let models = v0_3["userConfig"]["selectedModels"]
            .as_array()
            .expect("selectedModels");
        assert!(models.iter().any(|m| m.as_str() == Some("gpt-4o-mini")));
        assert_eq!(
            v0_3["userConfig"]["settings"]["timeout"].as_str(),
            Some("30")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/add")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"tsCode":"export default { id: 'probe' }"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, added) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "added={added}");
        let custom_vendor_id = added["vendorId"]
            .as_str()
            .expect("custom vendor id")
            .to_string();
        assert!(custom_vendor_id.starts_with("custom-"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/update-code")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"id":"{custom_vendor_id}","tsCode":"export default {{ updated: true }}"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, updated_code) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "updated_code={updated_code}");
        assert_eq!(
            updated_code["vendorId"].as_str(),
            Some(custom_vendor_id.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/vendors/summary")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, summary4) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "summary4={summary4}");
        let vendors4 = summary4["vendors"].as_array().expect("vendors array");
        assert!(vendors4
            .iter()
            .any(|v| v["userConfig"]["vendorId"].as_str() == Some(custom_vendor_id.as_str())));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/code-from-link")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"link":"https://example.com/vendor.ts"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, linked) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "linked={linked}");
        let linked_vendor_id = linked["vendorId"]
            .as_str()
            .expect("linked vendor id")
            .to_string();
        assert!(linked_vendor_id.starts_with("linked-"));
        assert_eq!(
            linked["link"].as_str(),
            Some("https://example.com/vendor.ts")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/delete")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"id":"{custom_vendor_id}"}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, deleted) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "deleted={deleted}");
        assert_eq!(
            deleted["vendorId"].as_str(),
            Some(custom_vendor_id.as_str())
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/delete")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"id":"{linked_vendor_id}"}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, deleted_linked) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "deleted_linked={deleted_linked}");
        assert_eq!(
            deleted_linked["vendorId"].as_str(),
            Some(linked_vendor_id.as_str())
        );

        // Disable vendor
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/enable")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"id":"{}","enable":0}}"#,
                        first_vendor_id_str
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, disabled) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "disabled={disabled}");
        assert_eq!(disabled["enabled"].as_bool(), Some(false));

        // Cleanup
        let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
            .bind(sub)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn novel_events_crud_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        // Create project
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        // Add novels first to have chapter_ids to associate
        let add_novel_body = format!(
            r#"{{"projectId":{},"data":[{{"index":1,"reel":"卷一","chapter":"第一章","chapterData":"第一章内容"}},{{"index":2,"reel":"卷一","chapter":"第二章","chapterData":"第二章内容"}}]}}"#,
            project_id
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/add-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(add_novel_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "add novels");

        // Create event
        let create_body =
            format!(r#"{{"name":"测试事件","detail":"事件详情","chapterIds":[1,2]}}"#);
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/novel-events",
                        project_id
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(create_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, event) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "create event={event}");
        assert_eq!(event["name"].as_str(), Some("测试事件"));
        let event_id = event["id"].as_i64().expect("event id") as i32;

        // List events
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/novel-events",
                        project_id
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "list={list}");
        assert_eq!(list["total"].as_i64(), Some(1));
        let items = list["items"].as_array().expect("items");
        assert_eq!(items.len(), 1);
        assert_eq!(items[0]["name"].as_str(), Some("测试事件"));
        let chapters = items[0]["chapterIndexes"].as_array().expect("chapters");
        assert_eq!(chapters.len(), 2);

        // Update event
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/novel-events/{}",
                        project_id, event_id
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"name":"更新后事件"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "update event");

        // Verify update
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/novel-events",
                        project_id
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list2) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "list2={list2}");
        assert_eq!(list2["items"][0]["name"].as_str(), Some("更新后事件"));

        // Delete event
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/novel-events/{}",
                        project_id, event_id
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "delete event");

        // Verify deletion
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{}/novel-events",
                        project_id
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, empty_list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "empty_list={empty_list}");
        assert_eq!(empty_list["total"].as_i64(), Some(0));

        // Cleanup
        let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
            .bind(project_id)
            .execute(&pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn novel_events_generate_events_async_fallback_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let add_novel_body = format!(
            r#"{{"projectId":{},"data":[{{"index":1,"reel":"卷一","chapter":"第一章","chapterData":"第一章内容"}},{{"index":2,"reel":"卷一","chapter":"第二章","chapterData":"第二章内容"}}]}}"#,
            project_legacy_id
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/add-novel")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(add_novel_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, add_msg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");

        let novel_rows: Vec<(i32,)> = sqlx::query_as(
            r#"
            SELECT n.legacy_id
            FROM public.app_novel n
            INNER JOIN public.app_project p ON p.id = n.project_id
            WHERE p.legacy_id = $1
              AND p.owner_user_id = $2
            ORDER BY n.chapter_index ASC, n.legacy_id ASC
            "#,
        )
        .bind(project_legacy_id)
        .bind(sub)
        .fetch_all(&pool)
        .await
        .expect("list novel legacy ids");
        let novel_legacy_ids: Vec<i32> = novel_rows.into_iter().map(|(id,)| id).collect();
        assert_eq!(novel_legacy_ids.len(), 2, "expected two novels");

        sqlx::query(
            r#"
            UPDATE public.app_novel n
            SET event = '历史事件', event_state = 1, error_reason = NULL
            FROM public.app_project p
            WHERE n.project_id = p.id
              AND p.legacy_id = $1
              AND p.owner_user_id = $2
              AND n.legacy_id = ANY($3)
            "#,
        )
        .bind(project_legacy_id)
        .bind(sub)
        .bind(&novel_legacy_ids)
        .execute(&pool)
        .await
        .expect("seed existing events");

        let payload = serde_json::json!({
            "projectId": project_legacy_id,
            "novelIds": novel_legacy_ids,
            "concurrentCount": 2
        });
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/events/generate-events")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(payload.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, body) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "generate-events body={body}");
        assert_eq!(body["message"].as_str(), Some("生成事件成功"));

        let reset_rows: Vec<(Option<String>, i32, Option<String>)> = sqlx::query_as(
            r#"
            SELECT n.event, n.event_state, n.error_reason
            FROM public.app_novel n
            INNER JOIN public.app_project p ON p.id = n.project_id
            WHERE p.legacy_id = $1
              AND p.owner_user_id = $2
              AND n.legacy_id = ANY($3)
            ORDER BY n.chapter_index ASC, n.legacy_id ASC
            "#,
        )
        .bind(project_legacy_id)
        .bind(sub)
        .bind(&novel_legacy_ids)
        .fetch_all(&pool)
        .await
        .expect("rows immediately after enqueue");
        assert!(
            reset_rows
                .iter()
                .all(|(event, state, reason)| event.is_none() && *state == 0 && reason.is_none()),
            "expected reset to pending before async extraction: {reset_rows:?}"
        );

        let mut final_rows: Vec<(i32, Option<String>, i32, Option<String>)> = Vec::new();
        for _ in 0..40 {
            final_rows = sqlx::query_as(
                r#"
                SELECT n.legacy_id, n.event, n.event_state, n.error_reason
                FROM public.app_novel n
                INNER JOIN public.app_project p ON p.id = n.project_id
                WHERE p.legacy_id = $1
                  AND p.owner_user_id = $2
                  AND n.legacy_id = ANY($3)
                ORDER BY n.chapter_index ASC, n.legacy_id ASC
                "#,
            )
            .bind(project_legacy_id)
            .bind(sub)
            .bind(&novel_legacy_ids)
            .fetch_all(&pool)
            .await
            .expect("poll extraction rows");
            if final_rows
                .iter()
                .all(|(_, _, state, _)| *state == -1 || *state == 1)
            {
                break;
            }
            tokio::time::sleep(std::time::Duration::from_millis(25)).await;
        }

        assert!(
            final_rows.iter().all(|(_, event, state, reason)| {
                event.is_none() && *state == -1 && reason.as_deref() == Some("llm_not_configured")
            }),
            "expected llm_not_configured fallback rows: {final_rows:?}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/novels/get-novel-event-state")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        serde_json::json!({ "ids": novel_legacy_ids }).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, state_rows) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "state_rows={state_rows}");
        let data = state_rows["data"].as_array().expect("state data array");
        assert_eq!(
            data.len(),
            2,
            "both novels should be visible in non-zero legacy event state list: {state_rows}"
        );
        assert!(
            data.iter()
                .all(|row| row["event_state"].as_i64() == Some(-1)),
            "legacy event_state should expose fallback failures: {state_rows}"
        );

        let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
            .bind(project_legacy_id)
            .execute(&pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_legacy_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn script_agent_plan_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/script-agent/get-plan-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, initial_plan) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "initial_plan={initial_plan}");
        assert_eq!(initial_plan["code"].as_i64(), Some(200));
        assert_eq!(initial_plan["data"]["storySkeleton"].as_str(), Some(""));
        assert_eq!(
            initial_plan["data"]["adaptationStrategy"].as_str(),
            Some("")
        );

        let set_body = serde_json::json!({
            "projectId": project_id,
            "agentType": "scriptAgent",
            "data": {
                "storySkeleton": "三幕短剧",
                "adaptationStrategy": "先冲突后反转",
                "script": [
                    { "name": "第1集", "content": "第一集内容" },
                    { "name": "第2集", "content": "第二集内容" }
                ]
            }
        })
        .to_string();
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/script-agent/set-plan-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(set_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, set_ok) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "set_ok={set_ok}");
        assert_eq!(set_ok["code"].as_i64(), Some(200));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/script-agent/get-plan-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, fetched_plan) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "fetched_plan={fetched_plan}");
        assert_eq!(
            fetched_plan["data"]["data"]["storySkeleton"].as_str(),
            Some("三幕短剧")
        );
        assert_eq!(
            fetched_plan["data"]["data"]["adaptationStrategy"].as_str(),
            Some("先冲突后反转")
        );
        let plan_id = fetched_plan["data"]["id"].as_i64().expect("plan id");
        let scripts = fetched_plan["data"]["data"]["script"]
            .as_array()
            .expect("scripts array");
        assert_eq!(scripts.len(), 2);
        assert_eq!(scripts[0]["name"].as_str(), Some("第1集"));
        assert_eq!(scripts[0]["content"].as_str(), Some("第一集内容"));
        let script_row_id = scripts[0]["id"].as_i64().expect("script row id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/script-agent/set-plan-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        serde_json::json!({
                            "projectId": project_id,
                            "agentType": "scriptAgent",
                            "data": {
                                "storySkeleton": "四幕短剧",
                                "adaptationStrategy": "强化人物弧光",
                                "script": [
                                    { "name": "第1集", "content": "第一集修订版" }
                                ]
                            }
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, set_again_ok) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "set_again_ok={set_again_ok}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/script-agent/get-plan-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, fetched_after_update) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "fetched_after_update={fetched_after_update}"
        );
        assert_eq!(
            fetched_after_update["data"]["data"]["storySkeleton"].as_str(),
            Some("四幕短剧")
        );
        let scripts_after_update = fetched_after_update["data"]["data"]["script"]
            .as_array()
            .expect("scripts_after_update");
        assert_eq!(
            scripts_after_update.len(),
            2,
            "existing unnamed rows preserved"
        );
        assert_eq!(
            scripts_after_update[0]["content"].as_str(),
            Some("第一集修订版")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/script-agent/update-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        serde_json::json!({
                            "id": plan_id,
                            "data": {
                                "storySkeleton": "终稿大纲",
                                "adaptationStrategy": "保留反转",
                                "script": [
                                    { "id": script_row_id, "content": "终稿正文" }
                                ]
                            }
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, updated_data) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "updated_data={updated_data}");
        assert_eq!(updated_data["data"].as_str(), Some("更新成功"));

        let stored_plan: Option<Value> = sqlx::query_scalar(
            r#"
            SELECT plan_data
            FROM public.app_script_agent_plan
            WHERE owner_user_id = $1
              AND project_id IN (
                SELECT id FROM public.app_project WHERE legacy_id = $2
              )
              AND agent_key = 'scriptAgent'
            "#,
        )
        .bind(sub)
        .bind(project_id)
        .fetch_optional(&pool)
        .await
        .expect("select plan_data");
        let stored_plan = stored_plan.expect("stored plan_data");
        assert_eq!(stored_plan["storySkeleton"].as_str(), Some("终稿大纲"));
        assert_eq!(stored_plan["adaptationStrategy"].as_str(), Some("保留反转"));
        assert_eq!(
            stored_plan["script"][0]["id"].as_i64(),
            Some(i64::from(script_row_id))
        );
        assert_eq!(
            stored_plan["script"][0]["content"].as_str(),
            Some("终稿正文")
        );

        let _ = sqlx::query(
            "DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)",
        )
        .bind(project_id)
        .execute(&pool)
        .await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn settings_memory_config_and_clear_agent_memories_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/memory-config")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, default_cfg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "default_cfg={default_cfg}");
        assert_eq!(default_cfg["messagesPerSummary"].as_i64(), Some(10));
        assert_eq!(default_cfg["modelDtype"].as_str(), Some("fp16"));

        let custom_cfg = r#"{"messagesPerSummary":12,"shortTermLimit":7,"summaryMaxLength":640,"summaryLimit":11,"ragLimit":4,"deepRetrieveSummaryLimit":6,"modelOnnxFile":["custom","onnx","model.onnx"],"modelDtype":"int8"}"#;
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/memory-config")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(custom_cfg))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, saved) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "saved={saved}");
        assert_eq!(saved["message"].as_str(), Some("保存设置成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/memory-config")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, fetched_cfg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "fetched_cfg={fetched_cfg}");
        assert_eq!(fetched_cfg["messagesPerSummary"].as_i64(), Some(12));
        assert_eq!(fetched_cfg["shortTermLimit"].as_i64(), Some(7));
        assert_eq!(fetched_cfg["modelDtype"].as_str(), Some("int8"));

        let stored_cfg: Option<Json<MemoryConfig>> = sqlx::query_scalar(
            "SELECT memory_config FROM public.app_user_profile WHERE user_id = $1",
        )
        .bind(sub)
        .fetch_optional(&pool)
        .await
        .expect("select memory_config");
        let stored_cfg = stored_cfg.expect("stored memory_config").0;
        assert_eq!(stored_cfg.messages_per_summary, 12);
        assert_eq!(stored_cfg.model_dtype, "int8");

        for body in [
            format!(
                r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7,"role":"user","content":"episode scoped memory"}}"#
            ),
            format!(
                r#"{{"projectId":{project_id},"agentType":"scriptAgent","role":"assistant","content":"project scoped memory"}}"#
            ),
        ] {
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri("/api/v1/agents/memory/append")
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(body))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, appended) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "appended={appended}");
            assert!(appended["id"].as_str().is_some());
        }

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/agents/memory/query")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, episode_memory) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "episode_memory={episode_memory}");
        assert_eq!(episode_memory.as_array().map(|a| a.len()), Some(1));
        assert_eq!(
            episode_memory[0]["content"][0]["data"].as_str(),
            Some("episode scoped memory")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/memory-config/clear-agent-memories")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, cleared) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "cleared={cleared}");
        assert_eq!(cleared["ok"].as_bool(), Some(true));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/agents/memory/query")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, episode_memory_after_clear) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "episode_memory_after_clear={episode_memory_after_clear}"
        );
        assert_eq!(
            episode_memory_after_clear.as_array().map(|a| a.len()),
            Some(0)
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/agents/memory/query")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, project_memory) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "project_memory={project_memory}");
        assert_eq!(project_memory.as_array().map(|a| a.len()), Some(1));
        assert_eq!(
            project_memory[0]["content"][0]["data"].as_str(),
            Some("project scoped memory")
        );

        let _ = sqlx::query(
            "DELETE FROM public.app_agent_memory WHERE owner_user_id = $1 AND legacy_project_id = $2",
        )
        .bind(sub)
        .bind(project_id)
        .execute(&pool)
        .await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
            .bind(sub)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn vendor_credential_store_get_delete_roundtrip() {
        let _guard = vendor_credential_test_lock().await;
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        // Set encryption key for test
        std::env::set_var(
            "TOONFLOW_VENDOR_CREDENTIAL_KEY",
            "test-encryption-key-for-contract-tests",
        );

        let vendor_id = "openai";

        // Store credential
        let store_body = format!(
            r#"{{"vendorId":"{}","apiKey":"sk-test1234567890","apiSecret":"secret123","apiToken":"token123"}}"#,
            vendor_id
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/vendors/credential")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(store_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, stored) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "store credential={stored}");
        assert_eq!(stored["vendorId"].as_str(), Some(vendor_id));
        assert_eq!(stored["keyHint"].as_str(), Some("...7890"));
        assert_eq!(stored["hasSecret"].as_bool(), Some(true));
        assert_eq!(stored["hasToken"].as_bool(), Some(true));
        assert_eq!(
            stored["message"].as_str(),
            Some("Credential stored securely")
        );

        // Get credential metadata
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, got) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "get credential={got}");
        assert_eq!(got["vendorId"].as_str(), Some(vendor_id));
        assert_eq!(got["keyHint"].as_str(), Some("...7890"));
        assert_eq!(got["hasSecret"].as_bool(), Some(true));
        assert_eq!(got["hasToken"].as_bool(), Some(true));

        // Delete credential
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, deleted) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "delete credential={deleted}");
        assert_eq!(deleted["vendorId"].as_str(), Some(vendor_id));
        assert_eq!(deleted["message"].as_str(), Some("Credential deleted"));

        // Verify deletion - should get 404
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::NOT_FOUND,
            "credential should be deleted"
        );

        // Cleanup
        let _ = sqlx::query("DELETE FROM public.app_vendor_credential WHERE owner_user_id = $1")
            .bind(sub)
            .execute(&pool)
            .await;

        // Clean up env var
        std::env::remove_var("TOONFLOW_VENDOR_CREDENTIAL_KEY");
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn production_legacy_endpoints_minimal_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        // Create project, script, and storyboard for testing
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        // Create script
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, script) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "script={script}");
        let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;

        // Test get-production-data (empty ids should fail)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/get-production-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"ids":[]}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "empty ids should fail");

        // Test get-flow-data (minimal implementation)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/get-flow-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{},"episodesId":1}}"#,
                        project_id
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        // Returns 404 because no storyboards exist yet
        assert_eq!(status, StatusCode::NOT_FOUND, "no storyboards yet");

        // Test save-flow-data (minimal implementation)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/save-flow-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{},"episodesId":1,"data":{{}}}}"#,
                        project_id
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        // Returns 404 because no storyboards exist yet
        assert_eq!(status, StatusCode::NOT_FOUND, "no storyboards yet");

        // Test workbench/generate-video (minimal implementation)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/generate-video")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{},"scriptId":{},"uploadData":[],"prompt":"test","model":"test","mode":"test","resolution":"720p","duration":5,"trackId":1}}"#,
                        project_id, script_id
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        // Returns 200 because project/script ownership is verified
        assert_eq!(status, StatusCode::OK, "generate-video minimal ok");

        // Test storyboard/polling-image (empty ids should fail)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/storyboard/polling-image")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"ids":[]}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "empty ids should fail");

        // Test export-image (empty shot_id should fail)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/export-image")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"shotId":[]}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "empty shotId should fail");

        // Test workbench/get-video-list (implemented; empty list is fine)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/get-video-list")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, body) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "get-video-list should return 200");
        assert_eq!(body["total"].as_i64(), Some(0));

        // Cleanup
        let _ = sqlx::query("DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
            .bind(project_id)
            .execute(&pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test settings_agent_deploy_roundtrip -- --ignored"]
    async fn settings_agent_deploy_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/agent-deploy/list")
                    .method(Method::POST)
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, before) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "before={before}");
        assert_eq!(before[0]["key"].as_str(), Some("scriptAgent"));
        assert_eq!(before[0]["model"].as_str(), Some(""));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/agent-deploy/deploy-model")
                    .method(Method::POST)
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"id":1,"name":"剧本Agent","model":"gpt-4.1","modelName":"GPT-4.1","vendorId":"openai","desc":"probe"}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, saved) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "saved={saved}");
        assert_eq!(saved["key"].as_str(), Some("scriptAgent"));
        assert_eq!(saved["message"].as_str(), Some("保存成功"));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/agent-deploy/list")
                    .method(Method::POST)
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, after) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "after={after}");
        assert_eq!(after[0]["model"].as_str(), Some("gpt-4.1"));
        assert_eq!(after[0]["modelName"].as_str(), Some("GPT-4.1"));
        assert_eq!(after[0]["vendorId"].as_str(), Some("openai"));

        let stored: Option<Value> = sqlx::query_scalar(
            r#"
            SELECT agent_deploy_config
            FROM public.app_user_profile
            WHERE user_id = $1
            "#,
        )
        .bind(sub)
        .fetch_optional(&pool)
        .await
        .expect("select agent_deploy_config");
        let stored = stored.expect("stored agent_deploy_config");
        assert_eq!(
            stored["rows"]["scriptAgent"]["model"].as_str(),
            Some("gpt-4.1")
        );

        let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
            .bind(sub)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn production_workbench_video_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"name":"pg_video_script"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, script) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "script={script}");
        let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/scripts/legacy/{script_id}/storyboards"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"prompt":"pg_video_storyboard","duration":"5","track_id":7,"flow_id":21,"sb_index":1}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, storyboard) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "storyboard={storyboard}");
        let storyboard_id = storyboard["legacy_id"]
            .as_i64()
            .expect("storyboard legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/scripts/legacy/{script_id}/storyboards"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"prompt":"pg_video_storyboard_two","duration":"6","track_id":9,"flow_id":22,"sb_index":2}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, storyboard_two) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::CREATED,
            "storyboard_two={storyboard_two}"
        );
        let storyboard_two_id = storyboard_two["legacy_id"]
            .as_i64()
            .expect("storyboard_two legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/get-production-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, production_data) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "production_data={production_data}");
        assert_eq!(
            production_data["data"][0]["id"].as_i64(),
            Some(i64::from(storyboard_id))
        );
        assert_eq!(
            production_data["data"][0]["trackId"].as_i64(),
            Some(7),
            "storyboard create should persist track"
        );
        assert_eq!(
            production_data["data"][0]["flowId"].as_i64(),
            Some(21),
            "storyboard create should persist flow"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/get-flow-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"episodesId":{script_id}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, initial_flow_data) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "initial_flow_data={initial_flow_data}"
        );
        assert_eq!(
            initial_flow_data["script"].as_str(),
            Some(""),
            "default flow should expose script content"
        );
        assert_eq!(
            initial_flow_data["storyboard"].as_array().map(Vec::len),
            Some(2)
        );
        assert_eq!(
            initial_flow_data["storyboard"][0]["id"].as_i64(),
            Some(i64::from(storyboard_id))
        );
        assert_eq!(
            initial_flow_data["storyboard"][1]["id"].as_i64(),
            Some(i64::from(storyboard_two_id))
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/save-flow-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        serde_json::json!({
                            "projectId": project_id,
                            "episodesId": script_id,
                            "data": {
                                "scriptPlan": "plan-v1",
                                "storyboardTable": "table-v1",
                                "storyboard": [
                                    {"id": storyboard_two_id, "associateAssetsIds": [11, 12]},
                                    {"id": storyboard_id, "associateAssetsIds": [21]},
                                ],
                                "extraPanel": {"zoom": 125},
                            }
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(
            res.status(),
            StatusCode::OK,
            "save-flow-data should accept owned project"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/get-flow-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"episodesId":{script_id}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, saved_flow_data) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "saved_flow_data={saved_flow_data}");
        assert_eq!(saved_flow_data["scriptPlan"].as_str(), Some("plan-v1"));
        assert_eq!(
            saved_flow_data["storyboardTable"].as_str(),
            Some("table-v1")
        );
        assert_eq!(saved_flow_data["extraPanel"]["zoom"].as_i64(), Some(125));
        assert_eq!(
            saved_flow_data["storyboard"][0]["id"].as_i64(),
            Some(i64::from(storyboard_two_id)),
            "saved storyboard order should drive later get-flow-data ordering"
        );
        assert_eq!(
            saved_flow_data["storyboard"][0]["associateAssetsIds"][0].as_i64(),
            Some(11)
        );
        assert_eq!(
            saved_flow_data["storyboard"][1]["id"].as_i64(),
            Some(i64::from(storyboard_id))
        );
        let reordered_indexes: Vec<(i32, Option<i32>)> = sqlx::query_as(
            r#"
            SELECT legacy_id, sb_index
            FROM app_storyboard
            WHERE legacy_id = ANY($1::int4[])
            ORDER BY legacy_id ASC
            "#,
        )
        .bind(vec![storyboard_id, storyboard_two_id])
        .fetch_all(&pool)
        .await
        .expect("query reordered storyboard indexes");
        assert_eq!(
            reordered_indexes,
            vec![(storyboard_id, Some(1)), (storyboard_two_id, Some(0))]
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/storyboard/polling-image")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(
            res.status(),
            StatusCode::OK,
            "polling-image should accept owned storyboard"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/export-image")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"shotId":[{{"id":"{storyboard_id}"}}]}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(
            res.status(),
            StatusCode::OK,
            "export-image should accept owned storyboard"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/add-track")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"scriptId":{script_id},"trackName":"B-roll"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, add_track) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "add_track={add_track}");
        assert_eq!(
            add_track["track_id"].as_i64(),
            Some(8),
            "add-track should allocate next track id"
        );
        let persisted_track_count: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*)
            FROM app_video_track vt
            INNER JOIN app_project p ON p.id = vt.project_id
            INNER JOIN app_script s ON s.id = vt.script_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
              AND s.legacy_id = $3
              AND vt.legacy_id = $4
            "#,
        )
        .bind(sub)
        .bind(project_id)
        .bind(script_id)
        .bind(8_i32)
        .fetch_one(&pool)
        .await
        .expect("query persisted video track");
        assert_eq!(
            persisted_track_count, 1,
            "add-track should persist app_video_track row"
        );

        let selected_video_url = "https://cdn.example.com/pg-contract-video.mp4";
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/select-video")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"scriptId":{script_id},"storyboardId":{storyboard_id},"videoUrl":"{selected_video_url}"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, selected) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "selected={selected}");
        assert_eq!(selected["video_url"].as_str(), Some(selected_video_url));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/get-video-list")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"trackId":7}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, track_videos) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "track_videos={track_videos}");
        assert_eq!(track_videos["total"].as_i64(), Some(1));
        assert_eq!(
            track_videos["videos"][0]["id"].as_i64(),
            Some(i64::from(storyboard_id))
        );
        assert_eq!(
            track_videos["videos"][0]["video_url"].as_str(),
            Some(selected_video_url)
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/delete-track")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"scriptId":{script_id},"trackId":7}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, deleted_track) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "deleted_track={deleted_track}");
        assert_eq!(deleted_track["track_id"].as_i64(), Some(7));
        let deleted_track_count: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*)
            FROM app_video_track vt
            INNER JOIN app_project p ON p.id = vt.project_id
            INNER JOIN app_script s ON s.id = vt.script_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
              AND s.legacy_id = $3
              AND vt.legacy_id = $4
            "#,
        )
        .bind(sub)
        .bind(project_id)
        .bind(script_id)
        .bind(7_i32)
        .fetch_one(&pool)
        .await
        .expect("query deleted video track");
        assert_eq!(
            deleted_track_count, 0,
            "delete-track should remove persisted app_video_track row"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/get-production-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, cleared_track_data) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "cleared_track_data={cleared_track_data}"
        );
        assert!(
            cleared_track_data["data"][0]["trackId"].is_null(),
            "delete-track should clear storyboard track assignment"
        );
        assert_eq!(
            cleared_track_data["data"][0]["url"].as_str(),
            Some(selected_video_url),
            "delete-track must not remove selected video"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/get-video-list")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"trackId":7}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, filtered_after_delete_track) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "filtered_after_delete_track={filtered_after_delete_track}"
        );
        assert_eq!(filtered_after_delete_track["total"].as_i64(), Some(0));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/get-video-list")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"projectId":{project_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, all_videos_before_delete_video) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "all_videos_before_delete_video={all_videos_before_delete_video}"
        );
        assert_eq!(all_videos_before_delete_video["total"].as_i64(), Some(1));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/delete-video")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"scriptId":{script_id},"storyboardId":{storyboard_id}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, deleted_video) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "deleted_video={deleted_video}");
        assert_eq!(
            deleted_video["storyboard_id"].as_i64(),
            Some(i64::from(storyboard_id))
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/get-production-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, after_delete_video) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "after_delete_video={after_delete_video}"
        );
        assert!(after_delete_video["data"][0]["url"].is_null());
        assert!(after_delete_video["data"][0]["state"].is_null());

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/workbench/get-video-list")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"projectId":{project_id}}}"#)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, all_videos_after_delete_video) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "all_videos_after_delete_video={all_videos_after_delete_video}"
        );
        assert_eq!(all_videos_after_delete_video["total"].as_i64(), Some(0));

        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
    async fn production_assets_derivative_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{project_id}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"name":"pg_derivative_asset","type":"role","description":"hero"}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, asset) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "asset={asset}");
        let asset_id = asset["legacy_id"].as_i64().expect("asset legacy_id") as i32;

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/assets/get-assets-data")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"assetType":"role","limit":10,"offset":0}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, assets_data) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "assets_data={assets_data}");
        assert_eq!(assets_data["total"].as_i64(), Some(1));
        assert_eq!(
            assets_data["assets"][0]["id"].as_i64(),
            Some(i64::from(asset_id))
        );

        let image_url = "https://cdn.example.com/pg-asset-derivative.png";
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/assets/update-assets-url")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"assetId":{asset_id},"imageUrl":"{image_url}"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, updated_url) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "updated_url={updated_url}");
        assert_eq!(updated_url["asset_id"].as_i64(), Some(i64::from(asset_id)));
        assert_eq!(updated_url["image_url"].as_str(), Some(image_url));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/assets/polling-image")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"assetIds":[{asset_id}]}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, polling) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "polling={polling}");
        assert_eq!(
            polling["statuses"][0]["asset_id"].as_i64(),
            Some(i64::from(asset_id))
        );
        assert_eq!(polling["statuses"][0]["image_count"].as_i64(), Some(1));
        assert_eq!(
            polling["statuses"][0]["latest_state"].as_str(),
            Some("已完成")
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/assets/delete-assets-derivative")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"assetIds":[{asset_id}]}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, deleted) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "deleted={deleted}");
        assert_eq!(deleted["deleted"].as_i64(), Some(1));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/production/assets/polling-image")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"projectId":{project_id},"assetIds":[{asset_id}]}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, polling_after_delete) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "polling_after_delete={polling_after_delete}"
        );
        assert_eq!(
            polling_after_delete["statuses"][0]["image_count"].as_i64(),
            Some(0)
        );
        assert!(polling_after_delete["statuses"][0]["latest_state"].is_null());

        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn prompts_patch_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        // Get prompts list
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "list prompts");
        assert_eq!(
            list.as_array().map(|a| a.len()),
            Some(3),
            "should have 3 default prompts"
        );

        // Get single prompt
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts/1")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, prompt) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "get prompt");
        assert_eq!(prompt["id"].as_i64(), Some(1));
        let original_data = prompt["data"].as_str().expect("data").to_string();

        // Patch prompt
        let new_data = "patched prompt data for testing";
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri("/api/v1/prompts/1")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"data":"{}"}}"#, new_data)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, patched) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "patch prompt");
        assert_eq!(patched["id"].as_i64(), Some(1));
        assert_eq!(patched["data"].as_str(), Some(new_data));

        // Verify patch persisted
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts/1")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, verify) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "verify patched prompt");
        assert_eq!(verify["data"].as_str(), Some(new_data));

        // Patch back to original
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri("/api/v1/prompts/1")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(r#"{{"data":"{}"}}"#, original_data)))
                    .unwrap(),
            )
            .await
            .unwrap();
        let status = res.status();
        assert_eq!(status, StatusCode::OK, "patch back should return 200");

        // Verify patch back persisted
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/prompts/1")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, restored) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "verify restored prompt");
        assert_eq!(restored["data"].as_str(), Some(original_data.as_str()));
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn storyboards_crud_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        // Create project
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        // Create script
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, script) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "script={script}");
        let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;

        // Get storyboards (empty)
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_id}/scripts/{script_id}/storyboards"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "list storyboards={list}");
        assert_eq!(list["items"].as_array().map(|a| a.len()), Some(0));

        // Cleanup
        let _ = sqlx::query(
            "DELETE FROM public.app_storyboard WHERE script_id IN (SELECT id FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1))"
        )
        .bind(project_id)
        .execute(&pool)
        .await;
        let _ = sqlx::query("DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
            .bind(project_id)
            .execute(&pool)
            .await;
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    #[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
    async fn scripts_crud_roundtrip() {
        let _ = dotenvy::dotenv();
        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
        let secret = std::env::var("SUPABASE_JWT_SECRET")
            .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

        let pool = PgPoolOptions::new()
            .max_connections(2)
            .connect(&url)
            .await
            .expect("connect DATABASE_URL");

        let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
        let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
        let app = build_router(contract_state(pool.clone(), secret));

        // Create project
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/projects")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from("{}"))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "created={created}");
        let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

        // Create script
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        r#"{"name":"test_script","content":"script content"}"#,
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, script) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "script={script}");
        let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;
        assert_eq!(script["name"].as_str(), Some("test_script"));

        // Get script
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, got) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "get script={got}");
        assert_eq!(got["legacy_id"].as_i64(), Some(i64::from(script_id)));

        // Update script
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"name":"updated_script"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, updated) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "update script={updated}");
        assert_eq!(updated["name"].as_str(), Some("updated_script"));

        // Delete script
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let status = res.status();
        assert_eq!(status, StatusCode::NO_CONTENT, "delete script");

        // Verify deletion
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "script should be deleted");

        // Cleanup
        let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
            .bind(project_id)
            .execute(&pool)
            .await;
    }

    #[tokio::test]
    async fn quality_reviews_require_bearer_token() {
        let (status, body) =
            post_json("/api/v1/quality/reviews", r#"{"targetType":"script"}"#).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");

        let (status, body) = get_json("/api/v1/quality/reviews").await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");

        let (status, body) = get_json("/api/v1/quality/stats").await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");

        let (status, body) = get_json("/api/v1/quality/stage-pass-rate").await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");
    }

    #[tokio::test]
    async fn quality_review_create_validates_payload_before_db_access() {
        let token = test_jwt(Uuid::new_v4());

        let (status, body) = post_json_bearer(
            "/api/v1/quality/reviews",
            &token,
            r#"{"targetType":"chapter"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
        assert_eq!(body["code"], "bad_request");

        let (status, body) = post_json_bearer(
            "/api/v1/quality/reviews",
            &token,
            r#"{"targetType":"script","source":"robot"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
        assert_eq!(body["code"], "bad_request");

        let (status, body) = post_json_bearer(
            "/api/v1/quality/reviews",
            &token,
            r#"{"targetType":"script","isBadCase":true,"badCaseCategory":"typo"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
        assert_eq!(body["code"], "bad_request");

        let (status, body) = post_json_bearer(
            "/api/v1/quality/reviews",
            &token,
            r#"{"targetType":"script","overallScore":11}"#,
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
        assert_eq!(body["code"], "bad_request");
    }

    #[tokio::test]
    async fn quality_reviews_list_validates_query_before_db_access() {
        let token = test_jwt(Uuid::new_v4());

        let (status, body) =
            get_json_bearer("/api/v1/quality/reviews?targetType=chapter", &token).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
        assert_eq!(body["code"], "bad_request");
    }

    #[tokio::test]
    async fn quality_endpoints_return_database_error_without_pool() {
        let token = test_jwt(Uuid::new_v4());
        let review_id = Uuid::nil();

        let (status, body) = post_json_bearer(
            "/api/v1/quality/reviews",
            &token,
            r#"{"targetType":"script"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
        assert_eq!(body["code"], "database_error");

        let (status, body) = get_json_bearer("/api/v1/quality/reviews", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
        assert_eq!(body["code"], "database_error");

        let (status, body) =
            get_json_bearer(&format!("/api/v1/quality/reviews/{review_id}"), &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
        assert_eq!(body["code"], "database_error");

        let (status, body) = get_json_bearer("/api/v1/quality/stats", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
        assert_eq!(body["code"], "database_error");

        let (status, body) = get_json_bearer("/api/v1/quality/stage-pass-rate", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
        assert_eq!(body["code"], "database_error");
    }
}
