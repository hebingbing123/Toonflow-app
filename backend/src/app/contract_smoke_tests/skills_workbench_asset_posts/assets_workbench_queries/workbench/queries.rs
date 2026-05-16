use super::super::super::super::helpers::*;
use super::super::super::WB_PROJECT;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn assets_get_assets_api_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/nested");
    let (status, v) = post_json(&uri, r#"{"type":"role"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_workbench_nested_rejects_invalid_asset_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/nested");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"type":"invalid"}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_assets_api_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/nested");
    let (status, v) =
        post_json_bearer(&uri, &token, r#"{"type":"role","page":1,"limit":10}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_image_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/image-bundle");
    let (status, v) = post_json(&uri, r#"{"assetsId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_image_rejects_non_positive_assets_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/image-bundle");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"assetsId":0}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/image-bundle");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"assetsId":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_material_data_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/material-data");
    let (status, v) = post_json(&uri, r#"{}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_material_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/material-data");
    let (status, v) = post_json_bearer(&uri, &token, r#"{}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
