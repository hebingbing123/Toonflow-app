use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn art_style_extract_prompt_requires_llm_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/art-styles/extract-prompt",
        &token,
        r#"{"images":["https://example.com/contract-smoke.png"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "llm_not_configured");
}

#[tokio::test]
async fn art_style_extract_prompt_empty_images_returns_bad_request_without_llm() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/art-styles/extract-prompt",
        &token,
        r#"{"images":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn art_style_extract_prompt_blank_image_returns_bad_request_without_llm() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/art-styles/extract-prompt",
        &token,
        r#"{"images":["  \t  "]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn art_style_extract_prompt_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/art-styles/extract-prompt",
        r#"{"images":["https://example.com/x.png"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
