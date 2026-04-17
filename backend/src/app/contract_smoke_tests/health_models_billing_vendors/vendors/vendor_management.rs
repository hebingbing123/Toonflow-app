use super::super::super::helpers::*;
use crate::app::vendor_credential_test_lock;
use axum::http::StatusCode;
use uuid::Uuid;

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
