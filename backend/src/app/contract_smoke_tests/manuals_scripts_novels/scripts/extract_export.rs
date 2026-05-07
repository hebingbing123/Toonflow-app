use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn scripts_export_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/scripts/export", &token, r#"{"numeric_ids":[1]}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_state_poll_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/scripts/extract-state/poll",
        &token,
        r#"{"numeric_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_assets_rejects_missing_project_before_db() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/scripts/extract-assets",
        &token,
        r#"{"script_numeric_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "v={v}");
}

#[tokio::test]
async fn scripts_extract_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/scripts/extract-assets",
        &token,
        r#"{"project_numeric_id":1,"script_numeric_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
