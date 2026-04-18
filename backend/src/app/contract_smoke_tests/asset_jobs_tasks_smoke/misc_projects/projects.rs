use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn projects_get_by_id_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_get_by_id_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_patch_empty_body_requires_database_before_validation_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
        r#"{}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
        r#"{"intro":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_smoke_projects_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_smoke_projects_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_empty_no_bearer("/api/v1/projects/00000000-0000-0000-0000-000000000001").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_smoke_projects_post_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_post_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/projects", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_smoke_projects_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        r#"{"name":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_smoke_projects_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
        r#"{"name":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
