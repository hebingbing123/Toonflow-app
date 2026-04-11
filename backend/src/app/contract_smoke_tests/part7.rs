use super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn storyboard_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/storyboards/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_styles_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/art-styles", r#"{"name":"smoke"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer("/api/v1/art-styles/legacy/1", r#"{"label":"x"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/art-styles/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_create_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/legacy/1/assets",
        r#"{"name":"smoke","type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_patch_unauthorized_without_bearer() {
    let (status, v) =
        patch_json_no_bearer("/api/v1/projects/legacy/1/assets/1", r#"{"name":"x"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_asset_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/projects/legacy/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_clear_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/clear",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_append_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/append",
        r#"{"projectId":1,"agentType":"scriptAgent","content":"hi"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_asset_link_put_unauthorized_without_bearer() {
    let (status, v) = put_empty_no_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_asset_unlink_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_styles_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_styles_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/art-styles", &token, r#"{"name":"smoke_style"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

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

#[tokio::test]
async fn art_style_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_cover_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/art-styles/legacy/1/cover", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        patch_json_bearer("/api/v1/art-styles/legacy/1", &token, r#"{"label":"x"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn art_style_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/art-styles/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
