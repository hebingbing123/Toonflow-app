use super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn corner_scape_assets_accepts_blank_types_entries_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/corner-scape",
        &token,
        r#"{"types":[" ","\n\t",""]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn corner_scape_assets_accepts_duplicate_types_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/corner-scape",
        &token,
        r#"{"types":["role","ROLE","scene","scene"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_post_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images",
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_list_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_list_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_get_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000")
            .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_get_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images/00000000-0000-0000-0000-000000000000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_post_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_patch_unauthorized_without_bearer() {
    let (status, v) = patch_json_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000",
        r#"{"sort_index":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
        r#"{"sort_index":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_patch_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images/00000000-0000-0000-0000-000000000000",
        &token,
        r#"{"sort_index":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_delete_unauthorized_without_bearer() {
    let (status, v) = delete_empty_no_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_file_get_unauthorized_without_bearer() {
    let (status, v) = get_json(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000/file",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn asset_image_file_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/00000000-0000-0000-0000-000000000000/file",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn asset_image_file_get_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/0/images/00000000-0000-0000-0000-000000000000/file",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn asset_image_file_get_rejects_malformed_image_id_uuid_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, body, _) = get_bytes_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/1/images/not-a-uuid/file",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert!(
        !body.is_empty(),
        "expected error body for invalid uuid path segment"
    );
}

#[tokio::test]
async fn project_assets_list_query_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets?script_legacy_id=1&page=1&limit=10").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_filtered_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs?kind=flutter.probe&status=queued").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn usage_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/usage/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn billing_webhook_events_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/webhooks/billing/events").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn billing_webhook_events_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?informational_event=true&provider=stripe&raw_event_id=evt_123&raw_event_id_prefix=evt_&event_type=invoice.payment_failed&provider_event_id=stripe:evt_123&provider_event_id_prefix=stripe:evt_&event_created_from=2026-04-01T00:00:00Z&event_created_to=2026-04-30T23:59:59Z&created_from=2026-04-01T00:00:00Z&created_to=2026-04-30T23:59:59Z&id_min=1&id_max=999999&sort=id_desc&limit=10&offset=0",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn billing_webhook_events_rejects_bad_created_from() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?created_from=not-a-time",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_bad_event_created_from() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_created_from=not-a-time",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_event_created_from_after_to() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_created_from=2026-04-30T23:59:59Z&event_created_to=2026-04-01T00:00:00Z",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_created_from_after_to() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?created_from=2026-04-30T23:59:59Z&created_to=2026-04-01T00:00:00Z",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_id_min_greater_than_id_max() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/webhooks/billing/events?id_min=10&id_max=1", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_event_type() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_type=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id_prefix() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?provider_event_id_prefix=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?provider_event_id=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?raw_event_id=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id_prefix() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?raw_event_id_prefix=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_unknown_provider() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/webhooks/billing/events?provider=foo", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_invalid_sort() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/webhooks/billing/events?sort=unknown", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn prompts_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/prompts").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn prompts_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/prompts/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_query_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/query",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_export_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/scripts/export", r#"{"legacy_ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_kinds_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/kinds").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_kinds_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/kinds/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_status_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/jobs/status/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/jobs", r#"{"kind":"flutter.probe","payload":{}}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn jobs_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn jobs_list_rejects_invalid_status_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?status=not-a-status", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_rejects_invalid_limit_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?limit=0", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_rejects_negative_offset_before_database() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/jobs?offset=-1", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn jobs_list_filtered_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/jobs?kind=flutter.probe&status=queued", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/tasks/get-project", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tasks_get_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/tasks/get-project", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_categories_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/tasks/get-task-categories", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_api_bad_page_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/get-task-api",
        &token,
        r#"{"page":0,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn tasks_get_task_api_large_page_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/get-task-api",
        &token,
        r#"{"page":2147483647,"limit":100}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_get_task_api_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/get-task-api",
        &token,
        r#"{"page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_int_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/tasks/task-details", &token, r#"{"taskId":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_bad_request_non_uuid_string_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/task-details",
        &token,
        r#"{"taskId":"not-a-uuid"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_numeric_string_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/tasks/task-details", &token, r#"{"taskId":"1"}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tasks_task_details_requires_database_for_uuid_task_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/tasks/task-details",
        &token,
        r#"{"taskId":"550e8400-e29b-41d4-a716-446655440000"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn general_get_single_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/general/get-single-project", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn general_get_single_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/general/get-single-project", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn general_update_project_requires_field_besides_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/general/update-project", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn general_update_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/general/update-project",
        &token,
        r#"{"id":1,"intro":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_get_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/project/get-project", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_get_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/project/get-project", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_delete_project_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/project/delete-project", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/project/delete-project", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_add_project_unauthorized_without_bearer() {
    let body = r#"{"projectType":"","name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","mode":""}"#;
    let (status, v) = post_json("/api/v1/project/add-project", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"projectType":"","name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","mode":""}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-project", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_edit_project_unauthorized_without_bearer() {
    let body = r#"{"id":1,"name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","projectType":"","mode":""}"#;
    let (status, v) = post_json("/api/v1/project/edit-project", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_edit_project_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"id":1,"name":"","intro":"","type":"","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","projectType":"","mode":""}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-project", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
