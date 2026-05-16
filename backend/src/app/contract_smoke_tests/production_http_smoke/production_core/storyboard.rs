use super::assert_database_error;

#[tokio::test]
async fn production_storyboard_polling_image_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/storyboard/polling-image",
        r#"{"projectId":1,"scriptId":1,"ids":[1]}"#,
    )
    .await;
}
