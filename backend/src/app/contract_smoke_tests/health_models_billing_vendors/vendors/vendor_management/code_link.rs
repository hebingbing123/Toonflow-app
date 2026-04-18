use super::{assert_bad_request, assert_database_error};

#[tokio::test]
async fn settings_vendors_code_from_link_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/settings/vendors/code-from-link",
        r#"{"link":"https://example.com/code.ts"}"#,
    )
    .await;
}

#[tokio::test]
async fn settings_vendors_code_from_link_rejects_empty_link_with_jwt() {
    assert_bad_request(
        "/api/v1/settings/vendors/code-from-link",
        r#"{"link":"  "}"#,
    )
    .await;
}

#[tokio::test]
async fn settings_vendors_code_from_link_rejects_non_http_link_with_jwt() {
    assert_bad_request(
        "/api/v1/settings/vendors/code-from-link",
        r#"{"link":"ftp://example.com/code.ts"}"#,
    )
    .await;
}
