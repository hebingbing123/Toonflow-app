use super::super::helpers::*;
use super::WB_PROJECT;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn assets_add_assets_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/add-assets");
    let (status, v) = post_json(&uri, r#"{"name":"hero","describe":"d","type":"role"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_add_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/add-assets");
    let (status, v) = post_json_bearer(
        &uri,
        &token,
        r#"{"name":"hero","describe":"d","type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_add_assets_rejects_invalid_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/add-assets");
    let (status, v) = post_json_bearer(
        &uri,
        &token,
        r#"{"name":"hero","describe":"d","type":"clip"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_save_assets_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/save-assets");
    let (status, v) = post_json(&uri, r#"{"id":1,"type":"role"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_save_assets_rejects_invalid_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/save-assets");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"id":1,"type":"clip"}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_save_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/save-assets");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"id":1,"type":"role","imageId":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_update_assets_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/update-assets");
    let (status, v) = post_json(&uri, r#"{"id":1,"name":"n","describe":"d"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_update_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/update-assets");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"id":1,"name":"n","describe":"d"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_del_assets_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/del-assets");
    let (status, v) = post_json(&uri, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_del_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/del-assets");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_batch_delete_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/batch-delete");
    let (status, v) = post_json(&uri, r#"{"id":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_batch_delete_rejects_empty_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/batch-delete");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"id":[]}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_del_image_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/del-image");
    let (status, v) = post_json(&uri, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_del_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/del-image");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_upload_clip_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/upload-clip");
    let (status, v) = post_json(
        &uri,
        r#"{"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_upload_clip_rejects_invalid_base64_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/upload-clip");
    let (status, v) = post_json_bearer(
        &uri,
        &token,
        r#"{"name":"smoke clip","base64Data":"data:image/png;base64,not-base64"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_empty_name_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/upload-clip");
    let (status, v) = post_json_bearer(
        &uri,
        &token,
        r#"{"name":" ","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_non_clip_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/upload-clip");
    let (status, v) = post_json_bearer(
        &uri,
        &token,
        r#"{"name":"smoke clip","type":"role","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_accepts_raw_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/upload-clip");
    let (status, v) =
        post_json_bearer(&uri, &token, r#"{"name":"smoke clip","base64Data":"AA=="}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_upload_clip_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/workbench/upload-clip");
    let (status, v) = post_json_bearer(
        &uri,
        &token,
        r#"{"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
