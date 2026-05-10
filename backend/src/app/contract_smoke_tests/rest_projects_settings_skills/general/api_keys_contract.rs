use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_api_keys_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/api-keys").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_api_keys_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/api-keys", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_api_keys_post_validates_display_name_before_db() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"displayName":"","scope":"read_only"}"#;
    let (status, v) = post_json_bearer("/api/v1/settings/api-keys", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_api_keys_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"displayName":"automation","scope":"read_write"}"#;
    let (status, v) = post_json_bearer("/api/v1/settings/api-keys", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
