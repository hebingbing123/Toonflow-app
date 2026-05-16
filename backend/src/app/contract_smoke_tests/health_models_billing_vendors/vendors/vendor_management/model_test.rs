use super::{assert_bad_request, assert_database_error};

#[tokio::test]
async fn settings_vendor_model_test_rejects_bad_type_with_jwt() {
    assert_bad_request(
        "/api/v1/settings/vendors/model-test",
        r#"{"modelName":"gpt-4o-mini","type":"audio","id":"1"}"#,
    )
    .await;
}

#[tokio::test]
async fn settings_vendor_model_test_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/settings/vendors/model-test",
        r#"{"modelName":"gpt-4o-mini","type":"text","id":"1"}"#,
    )
    .await;
}
