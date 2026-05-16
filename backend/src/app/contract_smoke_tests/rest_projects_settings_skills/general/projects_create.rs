use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn projects_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/projects", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
