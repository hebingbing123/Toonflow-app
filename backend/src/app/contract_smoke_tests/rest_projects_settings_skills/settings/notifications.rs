use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_notifications_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/notifications").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/notifications", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_mark_read_unauthorized_without_bearer() {
    let body = r#"{"ids":[1],"read":true}"#;
    let (status, v) = post_json("/api/v1/settings/notifications/mark-read", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_mark_read_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"ids":[1],"read":true}"#;
    let (status, v) =
        post_json_bearer("/api/v1/settings/notifications/mark-read", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_mark_all_read_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/notifications/mark-all-read", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_mark_all_read_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/notifications/mark-all-read", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_delete_unauthorized_without_bearer() {
    let body = r#"{"ids":[1]}"#;
    let (status, v) = post_json("/api/v1/settings/notifications/delete", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"ids":[1]}"#;
    let (status, v) = post_json_bearer("/api/v1/settings/notifications/delete", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_delete_read_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/notifications/delete-read", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_delete_read_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/notifications/delete-read", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_preferences_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/notifications/preferences").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_preferences_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/notifications/preferences", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_preferences_post_unauthorized_without_bearer() {
    let body = r#"{"mutedNotificationTypes":["platform.status"]}"#;
    let (status, v) = post_json("/api/v1/settings/notifications/preferences", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_preferences_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"mutedNotificationTypes":["platform.status"]}"#;
    let (status, v) =
        post_json_bearer("/api/v1/settings/notifications/preferences", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_preferences_reset_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/notifications/preferences/reset", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_preferences_reset_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/notifications/preferences/reset",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_preferences_apply_template_unauthorized_without_bearer() {
    let body = r#"{"template":"incident"}"#;
    let (status, v) = post_json(
        "/api/v1/settings/notifications/preferences/apply-template",
        body,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_preferences_apply_template_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"template":"incident"}"#;
    let (status, v) = post_json_bearer(
        "/api/v1/settings/notifications/preferences/apply-template",
        &token,
        body,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_preferences_export_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/notifications/preferences/export").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_preferences_export_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/settings/notifications/preferences/export", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_preferences_import_unauthorized_without_bearer() {
    let body = r#"{"envelope":{"preferences":{"mutedNotificationTypes":["platform.status"],"mutedWorkspaceIds":[],"mutedProjectIds":[],"deliverCriticalEvenMuted":true},"audit":{"updatedBy":"self","source":"import"}}}"#;
    let (status, v) = post_json("/api/v1/settings/notifications/preferences/import", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_preferences_import_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"envelope":{"preferences":{"mutedNotificationTypes":["platform.status"],"mutedWorkspaceIds":[],"mutedProjectIds":[],"deliverCriticalEvenMuted":true},"audit":{"updatedBy":"self","source":"import"}}}"#;
    let (status, v) = post_json_bearer(
        "/api/v1/settings/notifications/preferences/import",
        &token,
        body,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

// --- Workspace shared cleared-template audit export (sync + async + history + job file) ---

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_unauthorized_without_bearer() {
    let (status, v) = get_json(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export?format=json",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export?format=json",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_exports_unauthorized_without_bearer() {
    let (status, v) = get_json(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/exports",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_exports_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/exports",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_async_unauthorized_without_bearer() {
    let body = r#"{"format":"json"}"#;
    let (status, v) = post_json(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async",
        body,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_async_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"format":"json"}"#;
    let (status, v) = post_json_bearer(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async",
        &token,
        body,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_job_unauthorized_without_bearer() {
    let (status, v) = get_json(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/00000000-0000-0000-0000-000000000000",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_job_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/00000000-0000-0000-0000-000000000000",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_job_file_unauthorized_without_bearer()
{
    let (status, v) = get_json(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/00000000-0000-0000-0000-000000000000/file",
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_workspace_shared_audit_export_job_file_requires_database_with_jwt()
{
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/00000000-0000-0000-0000-000000000000/file",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
