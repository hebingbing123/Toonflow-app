use super::super::super::helpers::*;
use super::{assert_bad_request_get, assert_database_error_get, assert_unauthorized_get};
use axum::http::StatusCode;

#[tokio::test]
async fn jobs_list_unauthorized_without_bearer() {
    assert_unauthorized_get("/api/v1/jobs").await;
}

#[tokio::test]
async fn jobs_list_filtered_unauthorized_without_bearer() {
    assert_unauthorized_get("/api/v1/jobs?kind=flutter.probe&status=queued").await;
}

#[tokio::test]
async fn jobs_create_unauthorized_without_bearer() {
    let (status, value) =
        post_json("/api/v1/jobs", r#"{"kind":"flutter.probe","payload":{}}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_requires_database_with_jwt() {
    assert_database_error_get("/api/v1/jobs").await;
}

#[tokio::test]
async fn jobs_list_filtered_requires_database_with_jwt() {
    assert_database_error_get("/api/v1/jobs?kind=flutter.probe&status=queued").await;
}

#[tokio::test]
async fn jobs_list_rejects_invalid_status_before_database() {
    assert_bad_request_get("/api/v1/jobs?status=not-a-status").await;
}

#[tokio::test]
async fn jobs_list_rejects_invalid_limit_before_database() {
    assert_bad_request_get("/api/v1/jobs?limit=0").await;
}

#[tokio::test]
async fn jobs_list_rejects_negative_offset_before_database() {
    assert_bad_request_get("/api/v1/jobs?offset=-1").await;
}
