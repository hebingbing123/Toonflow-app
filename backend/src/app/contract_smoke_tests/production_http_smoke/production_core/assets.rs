use super::assert_database_error;

#[tokio::test]
async fn production_assets_get_assets_data_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/assets/get-assets-data",
        r#"{"projectId":1,"scriptId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_assets_batch_generate_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/assets/batch-generate-assets-image",
        r#"{"projectId":1,"scriptId":1,"assetIds":[1]}"#,
    )
    .await;
}

#[tokio::test]
async fn production_assets_delete_derivative_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/assets/delete-assets-derivative",
        r#"{"projectId":1,"scriptId":1,"assetIds":[1]}"#,
    )
    .await;
}

#[tokio::test]
async fn production_assets_polling_image_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/assets/polling-image",
        r#"{"projectId":1,"scriptId":1,"assetIds":[1]}"#,
    )
    .await;
}

#[tokio::test]
async fn production_assets_update_url_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/assets/update-assets-url",
        r#"{"projectId":1,"scriptId":1,"assetId":1,"imageUrl":"https://example.com/a.png"}"#,
    )
    .await;
}
