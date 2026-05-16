use super::{assert_bad_request, assert_database_error, assert_unauthorized};

#[tokio::test]
async fn production_edit_image_upload_image_unauthorized_without_bearer() {
    assert_unauthorized(
        "/api/v1/production/edit-image/upload-image",
        r#"{"projectId":1,"scriptId":1,"base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
}

#[tokio::test]
async fn production_edit_image_upload_image_rejects_unsupported_type_with_jwt() {
    assert_bad_request(
        "/api/v1/production/edit-image/upload-image",
        r#"{"projectId":1,"scriptId":1,"base64Data":"data:text/plain;base64,AA=="}"#,
    )
    .await;
}

#[tokio::test]
async fn production_edit_image_upload_image_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/edit-image/upload-image",
        r#"{"projectId":1,"scriptId":1,"base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_rejects_empty_flow_id_with_jwt() {
    assert_bad_request(
        "/api/v1/production/edit-image/generate-flow-image",
        r#"{"projectId":1,"scriptId":1,"flowId":"   ","prompt":"probe"}"#,
    )
    .await;
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_rejects_empty_prompt_with_jwt() {
    assert_bad_request(
        "/api/v1/production/edit-image/generate-flow-image",
        r#"{"projectId":1,"scriptId":1,"flowId":"img-flow-001","prompt":"   "}"#,
    )
    .await;
}

#[tokio::test]
async fn production_edit_image_generate_flow_image_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/edit-image/generate-flow-image",
        r#"{"projectId":1,"scriptId":1,"flowId":"img-flow-001","prompt":"probe"}"#,
    )
    .await;
}
