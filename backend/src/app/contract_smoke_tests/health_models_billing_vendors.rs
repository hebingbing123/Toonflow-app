use super::helpers::*;
use crate::app::vendor_credential_test_lock;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::HeaderValue;
use axum::http::Method;
use axum::http::Request;
use axum::http::StatusCode;
use hmac::{Hmac, Mac};
use sha2::Sha256;
use uuid::Uuid;
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
    assert_eq!(v["stub_placeholder"], "123");
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
