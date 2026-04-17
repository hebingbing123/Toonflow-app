use super::super::super::helpers::*;
use crate::settings::about::env_test_lock;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_about_check_update_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/settings/about/check-update",
        r#"{"source":"toonflow"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_about_check_update_stub_ok_with_jwt() {
    let _guard = env_test_lock().await;
    std::env::remove_var("TOONFLOW_UPDATE_LATEST_VERSION");
    std::env::remove_var("TOONFLOW_UPDATE_TIME");
    std::env::remove_var("TOONFLOW_UPDATE_TOONFLOW_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITHUB_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITEE_URL");
    std::env::remove_var("TOONFLOW_UPDATE_ATOMGIT_URL");
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/check-update",
        &token,
        r#"{"source":"github"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["needUpdate"], false);
    assert_eq!(v["reinstall"], false);
    assert!(v["latestVersion"].as_str().is_some_and(|s| !s.is_empty()));
    assert!(v["time"].as_str().is_some_and(|s| !s.is_empty()));
    assert!(v.get("url").is_none() || v["url"].is_null());
}

#[tokio::test]
async fn settings_about_check_update_uses_env_manifest_with_jwt() {
    let _guard = env_test_lock().await;
    std::env::set_var("TOONFLOW_UPDATE_LATEST_VERSION", "0.1.1");
    std::env::set_var("TOONFLOW_UPDATE_TIME", "2026-04-08T08:30:00Z");
    std::env::set_var(
        "TOONFLOW_UPDATE_GITHUB_URL",
        "https://example.com/toonflow-0.1.1.zip",
    );
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/about/check-update",
        &token,
        r#"{"source":"github"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["needUpdate"], true);
    assert_eq!(v["reinstall"], false);
    assert_eq!(v["latestVersion"], "0.1.1");
    let parsed_time =
        chrono::DateTime::parse_from_rfc3339(v["time"].as_str().expect("time should be string"))
            .expect("time should be rfc3339");
    assert_eq!(
        parsed_time.to_utc().to_rfc3339(),
        "2026-04-08T08:30:00+00:00"
    );
    assert_eq!(v["url"], "https://example.com/toonflow-0.1.1.zip");
    std::env::remove_var("TOONFLOW_UPDATE_LATEST_VERSION");
    std::env::remove_var("TOONFLOW_UPDATE_TIME");
    std::env::remove_var("TOONFLOW_UPDATE_TOONFLOW_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITHUB_URL");
    std::env::remove_var("TOONFLOW_UPDATE_GITEE_URL");
    std::env::remove_var("TOONFLOW_UPDATE_ATOMGIT_URL");
}

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
