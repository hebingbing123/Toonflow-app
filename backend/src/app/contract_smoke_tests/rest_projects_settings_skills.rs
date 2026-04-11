use super::helpers::*;
use crate::settings::about::env_test_lock;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::Method;
use axum::http::Request;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn projects_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/projects", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_state_poll_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-state/poll",
        r#"{"legacy_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_extract_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-assets",
        r#"{"project_legacy_id":1,"script_legacy_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboards_by_script_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/scripts/legacy/1/storyboards").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/storyboards/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn me_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/me").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

/// **`/api/v1/me`** does not require a Postgres pool: without **`DATABASE_URL`** it still returns **200** with default **`plan_tier`** (differs from most authenticated routes that return **503** `database_error`).
#[tokio::test]
async fn me_ok_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/me", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["plan_tier"], "free");
    assert!(
        v["sub"].as_str().is_some_and(|s| !s.is_empty()),
        "expected sub in me response"
    );
    // Without pool: daily_job_quota is the free-tier default (positive), jobs_today absent.
    assert!(
        v["daily_job_quota"].as_i64().is_some_and(|n| n > 0),
        "expected positive daily_job_quota without pool"
    );
    assert!(
        v["jobs_today"].is_null(),
        "jobs_today should be absent without pool"
    );
    assert!(
        v["subscription_status"].is_null(),
        "subscription_status should be absent without pool"
    );
    assert!(
        v["subscription_current_period_end_at"].is_null(),
        "subscription_current_period_end_at should be absent without pool"
    );
}

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

#[tokio::test]
async fn skills_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skills_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/content?path=script_execution_script.md").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_binary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/binary?path=_smoke/binary_probe.png").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_put_unauthorized_without_bearer() {
    let (status, v) = put_json(
        "/api/v1/skills/content",
        r#"{"path":"script_execution_script.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_put_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"../Cargo.toml","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_put_rejects_missing_file_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"__no_such_skill_file__.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_post_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/skills/content", r#"{"path":"x.md","content":"y"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_post_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"../README.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_post_conflict_when_file_exists() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"script_execution_script.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(v["code"], "conflict");
}

#[tokio::test]
async fn skill_content_post_get_delete_roundtrip() {
    let token = test_jwt(Uuid::nil());
    let name = format!("__contract_post_skill_{}.md", Uuid::new_v4());
    let body = serde_json::json!({
        "path": name.clone(),
        "content": "smoke_post_body",
    })
    .to_string();
    let (status, v) = post_json_bearer("/api/v1/skills/content", &token, &body).await;
    assert_eq!(status, StatusCode::CREATED, "v={v}");
    assert_eq!(v["path"], name);
    assert_eq!(v["content"], "smoke_post_body");

    let uri = format!("/api/v1/skills/content?path={name}");
    let (gstatus, gv) = get_json_bearer(&uri, &token).await;
    assert_eq!(gstatus, StatusCode::OK, "gv={gv}");
    assert_eq!(gv["content"], "smoke_post_body");

    let (dstatus, dv) = delete_json_bearer(&uri, &token).await;
    assert_eq!(dstatus, StatusCode::NO_CONTENT, "dv={dv}");
    assert!(dv.is_null());

    let (gone_status, _) = get_json_bearer(&uri, &token).await;
    assert_eq!(gone_status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn skill_content_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_json_no_bearer("/api/v1/skills/content?path=script_execution_script.md").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_delete_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_json_bearer("/api/v1/skills/content?path=../Cargo.toml", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_delete_not_found_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_json_bearer(
        "/api/v1/skills/content?path=__no_such_skill_for_delete__.md",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}

#[tokio::test]
async fn harness_tools_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/harness/tools").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_by_id_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}");
    let (status, v) = get_json(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_cancel_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/cancel");
    let (status, v) = post_empty_no_bearer(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_retry_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/retry");
    let (status, v) = post_empty_no_bearer(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_by_id_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_empty_no_bearer("/api/v1/projects/00000000-0000-0000-0000-000000000001").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_by_id_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
        r#"{"name":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_stats_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/stats",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/novels").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_list_search_unauthorized_without_bearer() {
    let (status, v) = get_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels?search=smoke&page=1&limit=10",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novels_create_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels",
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novel_by_legacy_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/novels/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novel_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels/1",
        r#"{"chapter":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novel_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_empty_no_bearer("/api/v1/projects/00000000-0000-0000-0000-000000000001/novels/1")
            .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn create_script_under_project_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts",
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn create_script_under_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/scripts/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer("/api/v1/scripts/legacy/1", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/scripts/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/scripts/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        patch_json_bearer("/api/v1/scripts/legacy/1", &token, r#"{"name":"smoke"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/scripts/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_create_under_script_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/scripts/legacy/1/storyboards", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer("/api/v1/storyboards/legacy/1", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer("/api/v1/storyboards/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboards_list_by_script_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/scripts/legacy/1/storyboards", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_create_under_script_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/scripts/legacy/1/storyboards", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/storyboards/legacy/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn storyboard_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/storyboards/legacy/1",
        &token,
        r#"{"prompt":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
