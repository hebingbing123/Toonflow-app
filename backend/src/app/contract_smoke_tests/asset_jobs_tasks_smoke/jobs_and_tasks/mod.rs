mod job_collection;
mod job_summaries;
mod tasks;

use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

async fn assert_unauthorized_get(path: &str) {
    let (status, value) = get_json(path).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

async fn assert_database_error_get(path: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer(path, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

async fn assert_bad_request_get(path: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer(path, &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(value["code"], "bad_request");
}
