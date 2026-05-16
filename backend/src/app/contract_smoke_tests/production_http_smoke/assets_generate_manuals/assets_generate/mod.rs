mod batch;
mod cancel;
mod generate;
mod skills;

use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

async fn assert_bad_request(path: &str, body: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(path, &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(value["code"], "bad_request");
}

async fn assert_database_error(path: &str, body: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(path, &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

async fn assert_unauthorized(path: &str, body: &str) {
    let (status, value) = post_json(path, body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}
