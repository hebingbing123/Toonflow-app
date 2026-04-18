use super::super::super::super::helpers::*;
use super::{assert_auth_not_configured_with_bearer, assert_unauthorized};
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn models_unauthorized_without_bearer() {
    assert_unauthorized("/api/v1/models").await;
}

/// With a valid-looking Bearer token, missing JWT secret must yield **503** `auth_not_configured` (not **503** `database_error`).
#[tokio::test]
async fn models_auth_not_configured_without_jwt_secret_even_with_bearer() {
    assert_auth_not_configured_with_bearer("/api/v1/models").await;
}

#[tokio::test]
async fn models_detail_unauthorized_without_bearer() {
    assert_unauthorized("/api/v1/models/detail?model_id=1%3Agpt-4o-mini").await;
}

#[tokio::test]
async fn models_list_ok_with_supabase_style_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/models", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = value.as_array().expect("models list is array");
    assert!(!arr.is_empty(), "embedded catalog must expose models");
    assert!(arr[0].get("id").is_some());
    assert!(arr[0].get("model_name").is_none());
    assert!(arr[0].get("value").is_some());
}

#[tokio::test]
async fn models_detail_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/models/detail?model_id=1%3Agpt-4o-mini";
    let (status, value) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["model_name"], "gpt-4o-mini");
    assert_eq!(value["vendor_id"], 1);
    assert_eq!(value["type"], "text");
}
