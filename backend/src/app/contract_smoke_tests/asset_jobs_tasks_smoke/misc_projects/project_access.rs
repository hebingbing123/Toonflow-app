use super::super::super::helpers::*;
use super::{PROJECTS_PATH, PROJECT_ID_PATH};
use axum::http::StatusCode;

#[tokio::test]
async fn projects_get_by_id_unauthorized_without_bearer() {
    let (status, value) = get_json(PROJECT_ID_PATH).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_list_unauthorized_without_bearer() {
    let (status, value) = get_json(PROJECTS_PATH).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_delete_unauthorized_without_bearer() {
    let (status, value) = delete_empty_no_bearer(PROJECT_ID_PATH).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_post_create_unauthorized_without_bearer() {
    let (status, value) = post_json(PROJECTS_PATH, "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_patch_unauthorized_without_bearer() {
    let (status, value) = patch_json_no_bearer(PROJECT_ID_PATH, r#"{"name":"x"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}
