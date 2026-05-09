use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_platform_config_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/platform-config").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_platform_config_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/platform-config", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_platform_config_post_unauthorized_without_bearer() {
    let body = r#"{
      "scope":"user",
      "toggles":{
        "helpHubEnabled":true,
        "qualityDashboardEnabled":true,
        "qualityRefreshControlsEnabled":true,
        "workspaceActivityEnabled":true,
        "benchmarkPaneEnabled":true,
        "jobsPaneEnabled":false
      }
    }"#;
    let (status, v) = post_json("/api/v1/settings/platform-config", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_platform_config_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{
      "scope":"user",
      "toggles":{
        "helpHubEnabled":true,
        "qualityDashboardEnabled":true,
        "qualityRefreshControlsEnabled":true,
        "workspaceActivityEnabled":true,
        "benchmarkPaneEnabled":true,
        "jobsPaneEnabled":false
      }
    }"#;
    let (status, v) = post_json_bearer("/api/v1/settings/platform-config", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
