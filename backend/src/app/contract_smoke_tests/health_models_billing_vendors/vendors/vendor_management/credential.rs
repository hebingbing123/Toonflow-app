use super::super::super::super::helpers::{post_json_bearer, test_jwt};
use super::{
    assert_database_error, assert_database_error_delete, assert_database_error_get, restore_env_var,
};
use crate::app::vendor_credential_test_lock;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_vendors_credential_requires_encryption_key_with_jwt() {
    let _guard = vendor_credential_test_lock().await;
    let prev = std::env::var_os("TOONFLOW_VENDOR_CREDENTIAL_KEY");
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
    restore_env_var("TOONFLOW_VENDOR_CREDENTIAL_KEY", prev);
}

#[tokio::test]
async fn settings_vendors_credential_requires_database_with_jwt() {
    let _guard = vendor_credential_test_lock().await;
    let prev = std::env::var_os("TOONFLOW_VENDOR_CREDENTIAL_KEY");
    std::env::set_var("TOONFLOW_VENDOR_CREDENTIAL_KEY", "test-credential-key");
    assert_database_error(
        "/api/v1/settings/vendors/credential",
        r#"{"vendorId":"openai","apiKey":"sk-test-1234"}"#,
    )
    .await;
    restore_env_var("TOONFLOW_VENDOR_CREDENTIAL_KEY", prev);
}

#[tokio::test]
async fn settings_vendors_get_credential_requires_database_with_jwt() {
    assert_database_error_get("/api/v1/settings/vendors/credential/openai").await;
}

#[tokio::test]
async fn settings_vendors_delete_credential_requires_database_with_jwt() {
    assert_database_error_delete("/api/v1/settings/vendors/credential/openai").await;
}
