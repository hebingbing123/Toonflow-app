use super::super::super::helpers::*;
use super::super::WB_PROJECT;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_assets_list_pagination_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets?page=1&limit=2");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

/// Combined list filters (parity with Electron-era **`getAssetsApi`** query surface).
#[tokio::test]
async fn project_assets_list_combined_filters_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!(
        "/api/v1/projects/{WB_PROJECT}/assets?script_numeric_id=1&asset_type=role&name=probe&page=1&limit=2"
    );
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_assets_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets");
    let (status, v) = post_json_bearer(
        &uri,
        &token,
        r#"{"name":"contract_smoke_role","type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_asset_link_put_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/scripts/1/assets/1");
    let (status, v) = put_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_asset_unlink_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/scripts/1/assets/1");
    let (status, v) = delete_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_get_by_numeric_id_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/1");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/1");
    let (status, v) = patch_json_bearer(&uri, &token, r#"{"name":"patched"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/1");
    let (status, v) = delete_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
