use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_members_list_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/projects/{id}/members");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_members_create_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/projects/{id}/members");
    let body = r#"{"userId":"00000000-0000-0000-0000-000000000002","role":"viewer"}"#;
    let (status, v) = post_json_bearer(&uri, &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_members_patch_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let pid = Uuid::nil();
    let uid = Uuid::nil();
    let uri = format!("/api/v1/projects/{pid}/members/{uid}");
    let (status, v) = patch_json_bearer(&uri, &token, r#"{"role":"editor"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_members_delete_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let pid = Uuid::nil();
    let uid = Uuid::nil();
    let uri = format!("/api/v1/projects/{pid}/members/{uid}");
    let (status, v) = delete_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
