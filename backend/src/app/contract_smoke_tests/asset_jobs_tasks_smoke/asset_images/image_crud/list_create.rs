use super::super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn asset_image_post_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images",
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_list_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_list_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_post_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
