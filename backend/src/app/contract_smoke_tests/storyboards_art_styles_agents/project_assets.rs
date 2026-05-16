use super::super::helpers::*;
use axum::http::StatusCode;

#[tokio::test]
async fn project_asset_create_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets",
        r#"{"name":"smoke","type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_get_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1",
        r#"{"name":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_empty_no_bearer("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1")
            .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_asset_link_put_unauthorized_without_bearer() {
    let (status, v) = put_empty_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/1/assets/1",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_asset_unlink_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/1/assets/1",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
