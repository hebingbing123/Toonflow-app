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
    use crate::notify_hub::WsNotifyHub;
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
        assert_eq!(v["source"], "static_catalog");
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
    async fn settings_agent_deploy_deploy_model_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/agent-deploy/deploy-model",
            &token,
            r#"{"id":1,"name":"剧本Agent","model":"x","modelName":"y","vendorId":null,"desc":"z"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn settings_agent_deploy_set_key_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            post_json_bearer("/api/v1/settings/agent-deploy/set-key", &token, "{}").await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
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
    async fn settings_vendor_model_test_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/model-test",
            &token,
            r#"{"modelName":"gpt-4o-mini","type":"text","id":"1"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn settings_vendors_add_unauthorized_without_bearer() {
        let (status, v) =
            post_json("/api/v1/settings/vendors/add", r#"{"tsCode":"export {}"}"#).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(v["code"], "unauthorized");
    }

    #[tokio::test]
    async fn settings_vendors_add_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/add",
            &token,
            r#"{"tsCode":"export {}"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn settings_vendors_update_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/update",
            &token,
            r#"{"id":"openai","inputValues":{},"inputs":[],"models":[]}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn settings_vendors_update_rejects_empty_id_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/update",
            &token,
            r#"{"id":"   ","inputValues":{},"inputs":[],"models":[]}"#,
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert_eq!(v["code"], "bad_request");
    }

    #[tokio::test]
    async fn settings_vendors_delete_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/delete",
            &token,
            r#"{"id":"openai"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn settings_vendors_enable_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/enable",
            &token,
            r#"{"id":"openai","enable":1}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn settings_vendors_update_code_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/update-code",
            &token,
            r#"{"id":"openai","tsCode":"//"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn settings_vendors_code_from_link_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/vendors/code-from-link",
            &token,
            r#"{"link":"https://example.com/a.ts"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
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
    async fn production_get_production_data_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/production/get-production-data",
            &token,
            r#"{"ids":[1]}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn production_get_flow_data_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/production/get-flow-data",
            &token,
            r#"{"projectId":1,"episodesId":1}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn production_save_flow_data_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/production/save-flow-data",
            &token,
            r#"{"projectId":1,"episodesId":1,"data":{}}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn production_workbench_generate_video_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/production/workbench/generate-video",
            &token,
            r#"{"projectId":1,"scriptId":1,"uploadData":[{"id":1,"sources":"assets"}],"prompt":"p","model":"1:x","mode":"std","resolution":"720p","duration":5,"trackId":1}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn production_storyboard_polling_image_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/production/storyboard/polling-image",
            &token,
            r#"{"ids":[1]}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn production_export_image_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/production/export-image",
            &token,
            r#"{"shotId":[{"id":"1"}]}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn production_assets_get_assets_data_stub_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/production/assets/get-assets-data",
            &token,
            r#"{"projectId":1}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn production_legacy_json_stub_rejects_non_object_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            post_json_bearer("/api/v1/production/assets/get-assets-data", &token, "[]").await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert_eq!(v["code"], "bad_request");
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
    async fn script_agent_get_plan_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/script-agent/get-plan-data",
            &token,
            r#"{"projectId":1,"agentType":"scriptAgent"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn script_agent_set_plan_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/script-agent/set-plan-data",
            &token,
            r#"{"projectId":1,"agentType":"scriptAgent","data":{"storySkeleton":"","adaptationStrategy":"","script":[]}}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn script_agent_update_data_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/script-agent/update-data",
            &token,
            r#"{"id":1,"data":{"storySkeleton":"","adaptationStrategy":"","script":[{"id":1,"content":""}]}}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
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
    async fn assets_generate_generate_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/assets-generate/generate",
            &token,
            r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn assets_generate_polish_prompt_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/assets-generate/polish-prompt",
            &token,
            r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"d"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn assets_generate_batch_generate_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/assets-generate/batch-generate",
            &token,
            r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
    }

    #[tokio::test]
    async fn assets_generate_batch_polish_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/assets-generate/batch-polish",
            &token,
            r#"{"projectId":1,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
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
    async fn tasks_task_details_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            post_json_bearer("/api/v1/tasks/task-details", &token, r#"{"taskId":1}"#).await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
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
    async fn settings_dev_switch_put_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = put_json_bearer(
            "/api/v1/settings/dev/switch-ai-tool",
            &token,
            r#"{"value":"0"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
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
    async fn settings_memory_config_get_post_roundtrip_same_state() {
        let state = smoke_state();
        let token = test_jwt(Uuid::nil());
        let (status, v) = oneshot_json_state(
            state.clone(),
            Request::builder()
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["messagesPerSummary"], 10);
        assert_eq!(v["ragLimit"], 3);
        let body = r#"{"messagesPerSummary":10,"shortTermLimit":5,"summaryMaxLength":500,"summaryLimit":10,"ragLimit":42,"deepRetrieveSummaryLimit":5,"modelOnnxFile":["all-MiniLM-L6-v2","onnx","model_fp16.onnx"],"modelDtype":"fp16"}"#;
        let (status2, v2) = oneshot_json_state(
            state.clone(),
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await;
        assert_eq!(status2, StatusCode::OK);
        assert_eq!(v2["message"], "保存设置成功");
        let (status3, v3) = oneshot_json_state(
            state,
            Request::builder()
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(status3, StatusCode::OK);
        assert_eq!(v3["ragLimit"], 42);
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
    async fn settings_about_download_app_not_implemented_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/settings/about/download-app",
            &token,
            r#"{"url":"https://example.com/app.dmg","reinstall":true}"#,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
        assert_eq!(v["code"], "not_implemented");
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
    use crate::notify_hub::WsNotifyHub;
    use crate::state::{AppState, MemoryConfig};

    const MAX_JSON: usize = 65_536;
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

    fn contract_state(pool: sqlx::PgPool, jwt_secret: String) -> AppState {
        AppState {
            pool: Some(pool),
            jwt_secret: Some(jwt_secret.into_bytes()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
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
}
