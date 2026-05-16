use super::super::super::super::helpers::*;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::StatusCode;
use axum::http::{header, Request};
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
async fn asset_image_list_rejects_non_positive_ids_with_zh_message() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json(
        Request::builder()
            .uri("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::ACCEPT_LANGUAGE, "zh-CN,zh;q=0.9,en;q=0.8")
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert_eq!(v["message"], "numeric ids 必须为正数");
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
