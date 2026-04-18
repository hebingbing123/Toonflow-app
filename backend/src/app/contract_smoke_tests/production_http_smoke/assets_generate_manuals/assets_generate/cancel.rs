use super::{assert_bad_request, assert_database_error, assert_unauthorized};

#[tokio::test]
async fn assets_generate_cancel_generate_unauthorized_without_bearer() {
    assert_unauthorized("/api/v1/assets-generate/cancel-generate", r#"{"id":1}"#).await;
}

#[tokio::test]
async fn assets_generate_cancel_generate_bad_request_non_positive_id_with_jwt() {
    assert_bad_request("/api/v1/assets-generate/cancel-generate", r#"{"id":0}"#).await;
}

#[tokio::test]
async fn assets_generate_cancel_generate_requires_database_with_jwt() {
    assert_database_error("/api/v1/assets-generate/cancel-generate", r#"{"id":1}"#).await;
}
