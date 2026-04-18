use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn jobs_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_filtered_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs?kind=flutter.probe&status=queued").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_kinds_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/kinds").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_kinds_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/kinds/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_status_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/status/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/jobs", r#"{"kind":"flutter.probe","payload":{}}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_list_rejects_invalid_status_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?status=not-a-status", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_rejects_invalid_limit_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?limit=0", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_rejects_negative_offset_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?offset=-1", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_filtered_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/jobs?kind=flutter.probe&status=queued", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
