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

#[tokio::test]
async fn workspace_members_list_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{id}/members");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspace_members_add_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{id}/members");
    let body = format!(r#"{{"user_id":"{id}","role":"member"}}"#);
    let (status, v) = post_json_bearer(&uri, &token, &body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspace_invites_create_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{id}/invites");
    let body = r#"{"email":"teammate@example.com","role":"member"}"#;
    let (status, v) = post_json_bearer(&uri, &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspace_invites_accept_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/workspaces/invites/accept",
        &token,
        r#"{"token":"dummy"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspace_members_patch_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{id}/members/{id}");
    let (status, v) = patch_json_bearer(&uri, &token, r#"{"role":"admin"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspace_members_delete_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{id}/members/{id}");
    let (status, v) = delete_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn workspace_members_leave_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{id}/members/me");
    let (status, v) = delete_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
