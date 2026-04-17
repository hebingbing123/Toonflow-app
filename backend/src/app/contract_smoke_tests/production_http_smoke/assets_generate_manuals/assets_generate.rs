use super::super::super::helpers::*;
use axum::http::StatusCode;
use serde_json::Value;
use uuid::Uuid;

#[tokio::test]
async fn assets_generate_generate_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_generate_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_generate_bad_request_empty_prompt_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"  "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_generate_bad_request_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":0,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_generate_accepts_raw_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/generate",
        &token,
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p","base64":"QUJDRA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_polish_prompt_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/polish-prompt",
        &token,
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"d"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_generate_polish_prompt_bad_request_empty_describe_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/polish-prompt",
        &token,
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"  "}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

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

#[tokio::test]
async fn assets_generate_cancel_generate_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets-generate/cancel-generate", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_generate_cancel_generate_bad_request_non_positive_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/cancel-generate",
        &token,
        r#"{"id":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_generate_cancel_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets-generate/cancel-generate",
        &token,
        r#"{"id":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn skills_list_ok_with_jwt_when_skills_tree_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/skills", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("skills list is array");
    assert!(!arr.is_empty());
    assert!(arr.iter().any(|e| {
        e.get("path")
            .and_then(Value::as_str)
            .is_some_and(|p| p.ends_with(".md"))
    }));
}
