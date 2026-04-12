use super::helpers::*;
use axum::http::StatusCode;
use serde_json::Value;
use uuid::Uuid;
#[tokio::test]
async fn production_get_flow_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-flow-data",
        &token,
        r#"{"projectId":1,"episodesId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_save_flow_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/save-flow-data",
        &token,
        r#"{"projectId":1,"episodesId":1,"data":{}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_workbench_generate_video_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/workbench/generate-video",
        &token,
        r#"{"projectId":1,"scriptId":1,"uploadData":[{"id":1,"sources":"assets"}],"prompt":"p","model":"1:x","mode":"std","resolution":"720p","duration":5,"trackId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_polling_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/polling-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_export_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/export-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"shotId":[{"id":"1"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_get_assets_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/get-assets-data",
        &token,
        r#"{"projectId":1,"scriptId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_batch_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/batch-generate-assets-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"assetIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_delete_derivative_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/delete-assets-derivative",
        &token,
        r#"{"projectId":1,"scriptId":1,"assetIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_polling_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/polling-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"assetIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_assets_update_url_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/assets/update-assets-url",
        &token,
        r#"{"projectId":1,"scriptId":1,"assetId":1,"imageUrl":"https://example.com/a.png"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

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

#[tokio::test]
async fn production_storyboard_add_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/add",
        &token,
        r#"{"projectId":1,"scriptId":1,"prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_batch_add_info_rejects_empty_storyboards_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/batch-add-info",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboards":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_get_storyboard_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-storyboard-data",
        &token,
        r#"{"projectId":1,"scriptId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_get_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/get-data",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_edit_info_rejects_empty_prompt_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/edit-info",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboardId":1,"prompt":"   "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn production_storyboard_edit_info_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/edit-info",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboardId":1,"prompt":"probe"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_remove_frame_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/remove-frame",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_update_url_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/update-url",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboardId":1,"imageUrl":"https://example.com/frame.png"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_preview_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/preview-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_storyboard_down_preview_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/storyboard/down-preview-image",
        &token,
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_get_plan_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/script-agent/get-plan-data",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_agent_get_plan_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/get-plan-data",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_set_plan_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/set-plan-data",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","data":{"storySkeleton":"","adaptationStrategy":"","script":[]}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_update_data_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/update-data",
        &token,
        r#"{"id":1,"data":{"storySkeleton":"","adaptationStrategy":"","script":[{"id":1,"content":""}]}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_generate_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_generate_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_generate_bad_request_empty_prompt_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"  "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_generate_bad_request_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":0,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_generate_accepts_raw_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p","base64":"QUJDRA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_polish_prompt_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/polish-prompt",
        &token,
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"d"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_polish_prompt_bad_request_empty_describe_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/polish-prompt",
        &token,
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"  "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_empty_items_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_zero_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","concurrentCount":0,"items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_excessive_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","concurrentCount":9999,"items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_accepts_data_uri_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_polish_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_empty_items_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"items":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_zero_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"concurrentCount":0,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_excessive_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"concurrentCount":9999,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_cancel_generate_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets-generate/cancel-generate", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_generate_cancel_generate_bad_request_non_positive_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/cancel-generate",
        &token,
        r#"{"id":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_cancel_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/cancel-generate",
        &token,
        r#"{"id":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn skills_list_ok_with_jwt_when_skills_tree_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/skills", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("skills list is array");
    assert!(!arr.is_empty());
    assert!(arr.iter().any(|e| {
        e.get("path")
            .and_then(Value::as_str)
            .is_some_and(|p| p.ends_with(".md"))
    }));
}

#[tokio::test]
async fn visual_manual_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/visual-manual").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn visual_manual_ok_with_jwt_when_art_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/visual-manual", &token).await;
    assert_eq!(status, StatusCode::OK, "visual_manual={v}");
    let styles = v["styles"].as_array().expect("styles");
    assert!(styles.len() >= 2, "expected multiple art_skills styles");
    assert!(
        styles
            .iter()
            .any(|s| s["stylePath"].as_str() == Some("2D_90s_japanese_anime")),
        "expected 2D_90s_japanese_anime in {styles:?}"
    );
}

#[tokio::test]
async fn visual_manual_post_ok_with_jwt_when_art_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/visual-manual", &token, "{}").await;
    assert_eq!(status, StatusCode::OK, "visual_manual_post={v}");
    let styles = v["styles"].as_array().expect("styles");
    assert!(styles.len() >= 2);
    assert!(styles
        .iter()
        .any(|s| s["stylePath"].as_str() == Some("2D_90s_japanese_anime")));
}

#[tokio::test]
async fn visual_manual_post_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/visual-manual", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
