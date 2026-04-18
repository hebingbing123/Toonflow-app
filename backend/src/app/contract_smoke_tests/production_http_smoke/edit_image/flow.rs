use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn production_edit_image_get_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(
        "/api/v1/production/edit-image/get-image-flow",
        &token,
        r#"{}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["flowId"], "img-flow-001");
}

#[tokio::test]
async fn production_edit_image_get_image_default_model_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(
        "/api/v1/production/edit-image/get-image-default-model",
        &token,
        r#"{}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["model"], "dall-e-3");
}

#[tokio::test]
async fn production_edit_image_save_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(
        "/api/v1/production/edit-image/save-image-flow",
        &token,
        r#"{"flowId":"img-flow-001","steps":[{"stepId":"upload","status":"done"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["saved"], true);
}

#[tokio::test]
async fn production_edit_image_update_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(
        "/api/v1/production/edit-image/update-image-flow",
        &token,
        r#"{"flowId":"img-flow-001","stepId":"generate","updates":{"status":"done"}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["updated"], true);
}
