use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn tasks_get_project_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tasks_get_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_categories_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/kinds", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_api_bad_page_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/page?page=0&limit=10", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn tasks_get_task_api_large_page_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/page?page=2147483647&limit=100", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_api_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/page?page=1&limit=10", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_int_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/task-detail/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_bad_request_non_uuid_string_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/task-detail/not-a-uuid", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_numeric_string_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/task-detail/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_uuid_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/jobs/task-detail/550e8400-e29b-41d4-a716-446655440000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
