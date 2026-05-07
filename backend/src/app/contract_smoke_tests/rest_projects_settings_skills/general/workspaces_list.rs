use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn workspaces_list_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/workspaces", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspaces_list_include_archived_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/workspaces?include_archived=true", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspaces_patch_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{id}");
    let (status, v) = patch_json_bearer(&uri, &token, r#"{"archive":true}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
