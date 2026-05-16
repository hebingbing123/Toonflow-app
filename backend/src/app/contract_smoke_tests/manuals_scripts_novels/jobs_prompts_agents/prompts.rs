use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

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
async fn prompts_patch_unknown_numeric_returns_404_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer("/api/v1/prompts/99", &token, r#"{"data":"x"}"#).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}

#[tokio::test]
async fn prompts_get_unknown_numeric_returns_404_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/prompts/99", &token).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}
