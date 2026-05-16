use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn art_styles_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/art-styles", r#"{"name":"smoke"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_patch_unauthorized_without_bearer() {
    let (status, v) =
        patch_json_no_bearer("/api/v1/art-styles/numeric/1", r#"{"label":"x"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/art-styles/numeric/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_styles_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_styles_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/art-styles", &token, r#"{"name":"smoke_style"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles/numeric/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_cover_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles/numeric/1/cover", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        patch_json_bearer("/api/v1/art-styles/numeric/1", &token, r#"{"label":"x"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/art-styles/numeric/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
