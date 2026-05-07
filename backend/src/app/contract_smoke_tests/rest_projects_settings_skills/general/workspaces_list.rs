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
