use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_vendors_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/vendors/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_vendors_summary_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/vendors/summary", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["source"], "static_catalog_with_user_config");
    let arr = v["vendors"].as_array().expect("vendors array");
    assert!(!arr.is_empty());
    assert!(arr[0]["id"].is_number());
    assert!(arr[0]["name"].as_str().is_some_and(|s| !s.is_empty()));
    assert!(arr[0]["modelCount"].as_i64().is_some_and(|n| n > 0));
}

#[tokio::test]
async fn settings_danger_delete_all_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/danger/delete-all-data", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_danger_delete_all_not_implemented_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/danger/delete-all-data", &token, "{}").await;
    assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
    assert_eq!(v["code"], "not_implemented");
}

#[tokio::test]
async fn settings_danger_clear_database_not_implemented_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/danger/clear-database", &token, "{}").await;
    assert_eq!(status, StatusCode::NOT_IMPLEMENTED);
    assert_eq!(v["code"], "not_implemented");
}
