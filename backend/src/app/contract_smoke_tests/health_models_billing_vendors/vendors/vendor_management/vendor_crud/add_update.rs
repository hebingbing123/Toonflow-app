use super::super::{assert_bad_request, assert_database_error, assert_unauthorized};

#[tokio::test]
async fn settings_vendors_add_unauthorized_without_bearer() {
    assert_unauthorized("/api/v1/settings/vendors/add", r#"{"tsCode":"export {}"}"#).await;
}

#[tokio::test]
async fn settings_vendors_add_requires_database_with_jwt() {
    assert_database_error("/api/v1/settings/vendors/add", r#"{"tsCode":"export {}"}"#).await;
}

#[tokio::test]
async fn settings_vendors_add_rejects_empty_ts_code_with_jwt() {
    assert_bad_request("/api/v1/settings/vendors/add", r#"{"tsCode":"   "}"#).await;
}

#[tokio::test]
async fn settings_vendors_update_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/settings/vendors/update",
        r#"{"id":"1","displayName":"OpenAI Custom","selectedModels":["gpt-4o-mini"],"settings":{}}"#,
    )
    .await;
}

#[tokio::test]
async fn settings_vendors_update_rejects_empty_id_with_jwt() {
    assert_bad_request(
        "/api/v1/settings/vendors/update",
        r#"{"id":"   ","displayName":"x"}"#,
    )
    .await;
}

#[tokio::test]
async fn settings_vendors_update_code_rejects_empty_ts_code_with_jwt() {
    assert_bad_request(
        "/api/v1/settings/vendors/update-code",
        r#"{"id":"custom-123","tsCode":"   "}"#,
    )
    .await;
}

#[tokio::test]
async fn settings_vendors_update_code_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/settings/vendors/update-code",
        r#"{"id":"custom-123","tsCode":"export {}"}"#,
    )
    .await;
}
