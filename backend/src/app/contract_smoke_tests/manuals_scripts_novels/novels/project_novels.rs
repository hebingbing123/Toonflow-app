use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

const SMOKE_PROJECT_UUID: &str = "00000000-0000-0000-0000-000000000001";

#[tokio::test]
async fn project_novels_list_unauthorized_without_bearer() {
    let (status, v) = get_json(&format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_create_unauthorized_without_bearer() {
    let (status, v) = post_json(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels"),
        r#"{"chapter":"c"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels"),
        &token,
        r#"{"chapter":"c"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_get_one_unauthorized_without_bearer() {
    let (status, v) = get_json(&format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/1")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_get_one_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/1"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_bad_page_requires_database_before_validation() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels?page=0&limit=10"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_empty_no_bearer(&format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/1")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/1"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/1"),
        r#"{"chapter":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/1"),
        &token,
        r#"{"chapter":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
