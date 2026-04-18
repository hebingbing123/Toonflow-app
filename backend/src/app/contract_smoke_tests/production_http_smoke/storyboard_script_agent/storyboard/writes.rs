use super::super::{assert_bad_request, assert_database_error};

#[tokio::test]
async fn production_storyboard_add_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/add",
        r#"{"projectId":1,"scriptId":1,"prompt":"probe"}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_edit_info_rejects_empty_prompt_with_jwt() {
    assert_bad_request(
        "/api/v1/production/storyboard/edit-info",
        r#"{"projectId":1,"scriptId":1,"storyboardId":1,"prompt":"   "}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_edit_info_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/edit-info",
        r#"{"projectId":1,"scriptId":1,"storyboardId":1,"prompt":"probe"}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_remove_frame_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/remove-frame",
        r#"{"projectId":1,"scriptId":1,"storyboardId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_storyboard_update_url_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/update-url",
        r#"{"projectId":1,"scriptId":1,"storyboardId":1,"imageUrl":"https://example.com/frame.png"}"#,
    )
    .await;
}
