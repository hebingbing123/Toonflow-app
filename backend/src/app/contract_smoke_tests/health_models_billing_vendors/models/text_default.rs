use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn models_text_default_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/models/text-default").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn models_text_default_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/models/text-default", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["stub_placeholder"], "123");
    assert_eq!(v["default_model_id"], "1:gpt-4o-mini");
}

#[tokio::test]
async fn models_text_default_patch_unauthorized_without_bearer() {
    let (status, v) =
        patch_json_no_bearer("/api/v1/models/text-default", r#"{"model_id":null}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn models_text_default_patch_rejects_unknown_model_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/models/text-default",
        &token,
        r#"{"model_id":"99:nonexistent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn models_text_default_patch_requires_database_with_valid_model_id() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/models/text-default",
        &token,
        r#"{"model_id":"1:gpt-4o-mini"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn models_text_default_patch_null_requires_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/models/text-default",
        &token,
        r#"{"model_id":null}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
