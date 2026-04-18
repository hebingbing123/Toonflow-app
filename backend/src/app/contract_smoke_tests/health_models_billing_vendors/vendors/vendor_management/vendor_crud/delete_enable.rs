use super::super::{assert_bad_request, assert_database_error};

#[tokio::test]
async fn settings_vendors_delete_rejects_empty_id_with_jwt() {
    assert_bad_request("/api/v1/settings/vendors/delete", r#"{"id":"   "}"#).await;
}

#[tokio::test]
async fn settings_vendors_delete_requires_database_with_jwt() {
    assert_database_error("/api/v1/settings/vendors/delete", r#"{"id":"custom-123"}"#).await;
}

#[tokio::test]
async fn settings_vendors_enable_rejects_empty_id_with_jwt() {
    assert_bad_request(
        "/api/v1/settings/vendors/enable",
        r#"{"id":"   ","enable":1}"#,
    )
    .await;
}

#[tokio::test]
async fn settings_vendors_enable_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/settings/vendors/enable",
        r#"{"id":"1","enable":1}"#,
    )
    .await;
}
