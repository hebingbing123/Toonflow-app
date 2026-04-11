use super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_query_director_manual_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/project/query-director-manual", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_query_director_manual_ok_with_jwt_when_story_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/project/query-director-manual", &token, "{}").await;
    assert_eq!(status, StatusCode::OK, "query_director_manual={v}");
    let data = v["data"].as_array().expect("data array");
    assert!(data.len() >= 2, "expected story_skills rows");
    assert!(data
        .iter()
        .any(|row| { row["directorManual"].as_str() == Some("Family_warmth") }));
}

#[tokio::test]
async fn project_add_director_manual_unauthorized_without_bearer() {
    let body = r#"{"name":"n","images":[],"directorManual":"n","data":[]}"#;
    let (status, v) = post_json("/api/v1/project/add-director-manual", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_director_manual_rejects_duplicate_bundle_folder() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"n","images":[],"directorManual":"Family_warmth","data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-director-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_edit_director_manual_not_found_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let body =
        r#"{"name":"t","directorManual":"__missing_director_manual_zz","images":[],"data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-director-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert_eq!(v["message"], "导演手册不存在");
}

#[tokio::test]
async fn project_delete_director_manual_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/project/delete-director-manual",
        r#"{"name":"Family_warmth"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_director_manual_rejects_pure_digit_name() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-director-manual",
        &token,
        r#"{"name":"123"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_delete_director_manual_ok_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-director-manual",
        &token,
        r#"{"name":"__contract_smoke_missing_story_skill"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "删除成功");
}

#[tokio::test]
async fn project_add_visual_manual_unauthorized_without_bearer() {
    let body = r#"{"name":"n","images":[],"stylePath":"n","data":[]}"#;
    let (status, v) = post_json("/api/v1/project/add-visual-manual", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_visual_manual_rejects_duplicate_bundle_style() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"n","images":[],"stylePath":"2D_90s_japanese_anime","data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-visual-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_edit_visual_manual_not_found_for_missing_style() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"t","stylePath":"__missing_visual_style_xx","images":[],"data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-visual-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert_eq!(v["message"], "视觉手册不存在");
}

#[tokio::test]
async fn project_delete_visual_manual_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/project/delete-visual-manual",
        r#"{"name":"2D_90s_japanese_anime"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_visual_manual_rejects_pure_digit_name() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-visual-manual",
        &token,
        r#"{"name":"42"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_delete_visual_manual_ok_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-visual-manual",
        &token,
        r#"{"name":"__contract_smoke_missing_art_style"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "删除成功");
}

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
async fn novels_get_novel_data_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/get-novel-data", r#"{"projectId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_get_novel_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel-data",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_get_novel_index_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel-index",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_get_novel_event_state_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/get-novel-event-state", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_get_novel_event_state_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel-event-state",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novel_events_generate_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/novels/events/generate-events",
        r#"{"projectId":1,"novelIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novel_events_generate_validates_payload_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/generate-events",
        &token,
        r#"{"projectId":1,"novelIds":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/generate-events",
        &token,
        r#"{"projectId":1,"novelIds":[1],"concurrentCount":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    // upper bound: concurrentCount > MAX_GENERATE_EVENTS_CONCURRENCY (20) → 400
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/generate-events",
        &token,
        r#"{"projectId":1,"novelIds":[1],"concurrentCount":9999}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novel_events_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/generate-events",
        &token,
        r#"{"projectId":1,"novelIds":[1],"concurrentCount":5}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_batch_delete_empty_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/novels/batch-delete", &token, r#"{"ids":[]}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_batch_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/novels/batch-delete", &token, r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novel_events_get_events_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/novels/events/get-events",
        r#"{"projectId":1,"page":1,"limit":20}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novel_events_get_events_validates_payload_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":0,"page":1,"limit":20}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":1,"page":0,"limit":20}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":1,"page":1,"limit":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novel_events_get_events_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/get-events",
        &token,
        r#"{"projectId":1,"page":1,"limit":20,"search":"事件"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novel_events_batch_delete_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/events/batch-delete", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novel_events_batch_delete_validates_payload_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/batch-delete",
        &token,
        r#"{"ids":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novel_events_batch_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/events/batch-delete",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_events_batch_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novel-events/batch-delete",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_get_novel_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/novels/get-novel",
        r#"{"projectId":1,"page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_get_novel_bad_page_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel",
        &token,
        r#"{"projectId":1,"page":0,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_get_novel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/get-novel",
        &token,
        r#"{"projectId":1,"page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_add_novel_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/add-novel", r#"{"projectId":1,"data":[]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_add_novel_empty_data_ok_with_jwt_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/novels/add-novel",
        &token,
        r#"{"projectId":1,"data":[]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "新增原文成功");
}

#[tokio::test]
async fn novels_add_novel_with_rows_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"projectId":1,"data":[{"index":1,"reel":"","chapter":"c","chapterData":"d"}]}"#;
    let (status, v) = post_json_bearer("/api/v1/novels/add-novel", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_delete_novel_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/novels/delete-novel", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_delete_novel_bad_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/novels/delete-novel", &token, r#"{"id":0}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_delete_novel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/novels/delete-novel", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novels_update_novel_unauthorized_without_bearer() {
    let body = r#"{"id":1,"index":1,"reel":"","chapter":"c","chapterData":"d","event":""}"#;
    let (status, v) = post_json("/api/v1/novels/update-novel", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novels_update_novel_bad_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"id":0,"index":1,"reel":"","chapter":"c","chapterData":"d","event":""}"#;
    let (status, v) = post_json_bearer("/api/v1/novels/update-novel", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novels_update_novel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"id":1,"index":1,"reel":"","chapter":"c","chapterData":"d","event":""}"#;
    let (status, v) = post_json_bearer("/api/v1/novels/update-novel", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/jobs",
        &token,
        r#"{"kind":"flutter.probe","payload":{}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn job_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}");
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn job_cancel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/cancel");
    let (status, v) = post_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn job_retry_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/retry");
    let (status, v) = post_empty_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_kinds_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/kinds", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_kinds_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/kinds/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_status_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs/status/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn usage_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/usage/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/prompts", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/prompts/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer("/api/v1/prompts/1", &token, r#"{"data":"patched"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn prompts_patch_unknown_legacy_returns_404_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer("/api/v1/prompts/99", &token, r#"{"data":"x"}"#).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}

#[tokio::test]
async fn prompts_get_unknown_legacy_returns_404_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/prompts/99", &token).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}

#[tokio::test]
async fn agents_memory_query_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/query",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn agents_memory_clear_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/clear",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn agents_memory_append_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/append",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","content":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_export_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/scripts/export", &token, r#"{"legacy_ids":[1]}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_state_poll_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/scripts/extract-state/poll",
        &token,
        r#"{"legacy_ids":[1]}"#,
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
        r#"{"project_legacy_id":1,"script_legacy_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
