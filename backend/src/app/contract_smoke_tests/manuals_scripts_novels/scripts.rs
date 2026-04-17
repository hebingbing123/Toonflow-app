use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn scripts_get_script_api_by_project_id_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/get-script-api",
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_get_script_api_by_project_id_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/get-script-api",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_batch_add_by_project_id_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/batch-add",
        r#"{"data":[{"scriptName":"a","scriptData":"b"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_batch_add_by_project_id_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/batch-add",
        &token,
        r#"{"data":[{"scriptName":"a","scriptData":"b"}]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

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
