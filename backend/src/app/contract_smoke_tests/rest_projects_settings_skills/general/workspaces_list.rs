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
async fn workspace_stats_internal_ops_token_gate_serial() {
    let _lock = internal_ops_token_test_lock();
    let prev = std::env::var("TOONFLOW_INTERNAL_OPS_TOKEN").ok();
    let workspace_id = Uuid::nil();
    let uri = format!("/api/v1/workspaces/{workspace_id}/stats");

    std::env::remove_var("TOONFLOW_INTERNAL_OPS_TOKEN");
    let (status, v) = get_json(&uri).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(v["code"], "forbidden");

    std::env::set_var("TOONFLOW_INTERNAL_OPS_TOKEN", "expected-secret");
    let (status, v) = get_json_internal_ops(&uri, Some("wrong")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");

    std::env::set_var("TOONFLOW_INTERNAL_OPS_TOKEN", "ops-test-token");
    let (status, v) = get_json_internal_ops(&uri, Some("ops-test-token")).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");

    restore_ops_token(prev);
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

fn restore_ops_token(prev: Option<String>) {
    match prev {
        Some(s) => std::env::set_var("TOONFLOW_INTERNAL_OPS_TOKEN", s),
        None => std::env::remove_var("TOONFLOW_INTERNAL_OPS_TOKEN"),
    }
}
