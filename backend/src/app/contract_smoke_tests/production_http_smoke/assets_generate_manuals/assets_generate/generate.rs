use super::super::super::super::helpers::*;
use axum::http::StatusCode;
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
