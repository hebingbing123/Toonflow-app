use super::{assert_bad_request, assert_database_error};

#[tokio::test]
async fn assets_generate_batch_generate_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/assets-generate/batch-generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_empty_items_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/batch-generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_zero_concurrent_count_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/batch-generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","concurrentCount":0,"items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_excessive_concurrent_count_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/batch-generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","concurrentCount":9999,"items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_generate_accepts_data_uri_base64_before_database_with_jwt() {
    assert_database_error(
        "/api/v1/assets-generate/batch-generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_polish_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/assets-generate/batch-polish",
        r#"{"projectId":1,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_empty_items_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/batch-polish",
        r#"{"projectId":1,"items":[]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_zero_concurrent_count_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/batch-polish",
        r#"{"projectId":1,"concurrentCount":0,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_excessive_concurrent_count_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/batch-polish",
        r#"{"projectId":1,"concurrentCount":9999,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
}
