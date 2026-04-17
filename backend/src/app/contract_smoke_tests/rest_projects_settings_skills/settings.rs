use super::super::helpers::*;
use crate::settings::about::env_test_lock;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::Method;
use axum::http::Request;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_dev_switch_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/dev/switch-ai-tool").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_dev_switch_get_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/dev/switch-ai-tool", &token).await;
    assert_eq!(status, StatusCode::OK);
    let val = v["value"].as_str().expect("value");
    assert!(val == "0" || val == "1");
}

#[tokio::test]
async fn settings_dev_switch_put_updates_process_local_value_with_jwt() {
    let state = smoke_state();
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json_state(
        state.clone(),
        Request::builder()
            .method(Method::PUT)
            .uri("/api/v1/settings/dev/switch-ai-tool")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(r#"{"value":"1"}"#.to_string()))
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["value"], "1");

    let (status, v) = oneshot_json_state(
        state,
        Request::builder()
            .uri("/api/v1/settings/dev/switch-ai-tool")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["value"], "1");
}

#[tokio::test]
async fn settings_dev_switch_put_rejects_non_binary_value_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/settings/dev/switch-ai-tool",
        &token,
        r#"{"value":"2"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn settings_memory_config_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/memory-config").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_memory_config_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/memory-config", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_memory_config_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"messagesPerSummary":10,"shortTermLimit":5,"summaryMaxLength":500,"summaryLimit":10,"ragLimit":3,"deepRetrieveSummaryLimit":5,"modelOnnxFile":["all-MiniLM-L6-v2","onnx","model_fp16.onnx"],"modelDtype":"fp16"}"#;
    let (status, v) = post_json_bearer("/api/v1/settings/memory-config", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_memory_config_clear_agent_memories_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/settings/memory-config/clear-agent-memories",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_memory_config_clear_agent_memories_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/memory-config/clear-agent-memories",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

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
