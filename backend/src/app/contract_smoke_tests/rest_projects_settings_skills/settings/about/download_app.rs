use super::super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_about_download_app_noop_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/download-app",
        &token,
        r#"{"url":"https://example.com/app.dmg","reinstall":true}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert!(v["message"].as_str().is_some_and(|s| s.contains("Flutter")));
}

#[tokio::test]
async fn settings_about_download_app_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/settings/about/download-app",
        r#"{"url":"https://example.com/app.dmg","reinstall":false}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_about_download_app_rejects_bad_url_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/download-app",
        &token,
        r#"{"url":"not-a-url","reinstall":false}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
