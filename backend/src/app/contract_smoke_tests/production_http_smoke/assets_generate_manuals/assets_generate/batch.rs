use super::super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn assets_generate_batch_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_empty_items_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_zero_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","concurrentCount":0,"items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_bad_request_excessive_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","concurrentCount":9999,"items":[{"id":1,"type":"role","name":"n","prompt":"p"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_generate_accepts_data_uri_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","items":[{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_polish_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_empty_items_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"items":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_zero_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"concurrentCount":0,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_batch_polish_bad_request_excessive_concurrent_count_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/batch-polish",
        &token,
        r#"{"projectId":1,"concurrentCount":9999,"items":[{"assetsId":1,"type":"role","name":"n","describe":"d"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
