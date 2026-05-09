use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_audit_list_requires_database_without_pool() {
    let token = test_jwt(Uuid::nil());
    let id = Uuid::nil();
    let uri = format!("/api/v1/projects/{id}/audit");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
