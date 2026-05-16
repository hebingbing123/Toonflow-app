use super::super::super::helpers::*;
use super::super::WB_PROJECT;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_novels_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/novels");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_pagination_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/novels?page=1&limit=5");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/novels");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"chapter":"smoke"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/novels/1");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/novels/1");
    let (status, v) = patch_json_bearer(&uri, &token, r#"{"chapter":"x"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/novels/1");
    let (status, v) = delete_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
