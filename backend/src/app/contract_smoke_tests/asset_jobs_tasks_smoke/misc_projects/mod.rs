mod misc;
mod project_access;
mod project_database;

use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

const PROJECT_ID_PATH: &str = "/api/v1/projects/00000000-0000-0000-0000-000000000001";
const PROJECTS_PATH: &str = "/api/v1/projects";

async fn assert_database_error_get(path: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer(path, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

async fn assert_database_error_post(path: &str, body: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(path, &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

async fn assert_database_error_patch(path: &str, body: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = patch_json_bearer(path, &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

async fn assert_database_error_delete(path: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = delete_empty_bearer(path, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}
