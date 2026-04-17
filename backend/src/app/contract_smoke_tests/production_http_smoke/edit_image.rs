use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn production_edit_image_get_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/get-image-flow",
        &token,
        r#"{}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["flowId"], "img-flow-001");
}

#[tokio::test]
async fn production_edit_image_get_image_default_model_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/get-image-default-model",
        &token,
        r#"{}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["model"], "dall-e-3");
}

#[tokio::test]
async fn production_edit_image_save_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/save-image-flow",
        &token,
        r#"{"flowId":"img-flow-001","steps":[{"stepId":"upload","status":"done"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["saved"], true);
}

#[tokio::test]
async fn production_edit_image_update_image_flow_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/update-image-flow",
        &token,
        r#"{"flowId":"img-flow-001","stepId":"generate","updates":{"status":"done"}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["updated"], true);
}

#[tokio::test]
async fn production_edit_image_upload_image_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/production/edit-image/upload-image",
        r#"{"projectId":1,"scriptId":1,"base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn production_edit_image_upload_image_rejects_unsupported_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/upload-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"base64Data":"data:text/plain;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_edit_image_upload_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/upload-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_rejects_empty_flow_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/generate-flow-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"flowId":"   ","prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_rejects_empty_prompt_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/generate-flow-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"flowId":"img-flow-001","prompt":"   "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/edit-image/generate-flow-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"flowId":"img-flow-001","prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
