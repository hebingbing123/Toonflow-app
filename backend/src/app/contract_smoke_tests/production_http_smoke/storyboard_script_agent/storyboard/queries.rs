use super::super::{assert_bad_request, assert_database_error};

#[tokio::test]
async fn production_storyboard_batch_add_info_rejects_empty_storyboards_with_jwt() {
    assert_bad_request(
        "/api/v1/production/storyboard/batch-add-info",
        r#"{"projectId":1,"scriptId":1,"storyboards":[]}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_batch_add_info_rejects_non_positive_duration_with_jwt() {
    assert_bad_request(
        "/api/v1/production/storyboard/batch-add-info",
        r#"{"projectId":1,"scriptId":1,"storyboards":[{"prompt":"probe","duration":0}]}"#,
    )
    .await;
}

#[tokio::test]
async fn production_get_storyboard_data_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/get-storyboard-data",
        r#"{"projectId":1,"scriptId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_get_data_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/get-data",
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_preview_image_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/preview-image",
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_down_preview_image_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/down-preview-image",
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
}
