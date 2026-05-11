use axum::{routing::get, Router};

use crate::state::AppState;

mod content_compliance_sync_pure;
mod handlers;
mod storage;
mod types;
pub(crate) mod workspace_audit_export;
pub(crate) mod workspace_audit_export_artifact_storage;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_delete_notifications, __path_delete_notifications_content_compliance_cleared_template,
    __path_delete_notifications_content_compliance_cleared_templates_shared,
    __path_delete_read_notifications, __path_get_notifications,
    __path_get_notifications_content_compliance_cleared_templates,
    __path_get_notifications_content_compliance_cleared_templates_export,
    __path_get_notifications_content_compliance_cleared_templates_shared,
    __path_get_notifications_content_compliance_cleared_templates_shared_audit,
    __path_get_notifications_content_compliance_cleared_templates_shared_audit_export,
    __path_get_notifications_content_compliance_cleared_templates_shared_audit_export_job,
    __path_get_notifications_content_compliance_cleared_templates_shared_audit_export_job_file,
    __path_get_notifications_content_compliance_cleared_templates_shared_audit_exports,
    __path_get_notifications_preferences, __path_get_notifications_preferences_export,
    __path_mark_all_notifications_read, __path_mark_notifications_read,
    __path_post_notifications_content_compliance_cleared_template,
    __path_post_notifications_content_compliance_cleared_template_apply,
    __path_post_notifications_content_compliance_cleared_template_reorder,
    __path_post_notifications_content_compliance_cleared_templates_import,
    __path_post_notifications_content_compliance_cleared_templates_shared,
    __path_post_notifications_content_compliance_cleared_templates_shared_audit_export_async,
    __path_post_notifications_content_compliance_sync, __path_post_notifications_preferences,
    __path_post_notifications_preferences_apply_template,
    __path_post_notifications_preferences_import, __path_post_notifications_preferences_reset,
};
pub(crate) use handlers::{
    delete_notifications, delete_notifications_content_compliance_cleared_template,
    delete_notifications_content_compliance_cleared_templates_shared, delete_read_notifications,
    get_notifications, get_notifications_content_compliance_cleared_templates,
    get_notifications_content_compliance_cleared_templates_export,
    get_notifications_content_compliance_cleared_templates_shared,
    get_notifications_content_compliance_cleared_templates_shared_audit,
    get_notifications_content_compliance_cleared_templates_shared_audit_export,
    get_notifications_content_compliance_cleared_templates_shared_audit_export_job,
    get_notifications_content_compliance_cleared_templates_shared_audit_export_job_file,
    get_notifications_content_compliance_cleared_templates_shared_audit_exports,
    get_notifications_preferences, get_notifications_preferences_export,
    mark_all_notifications_read, mark_notifications_read,
    post_notifications_content_compliance_cleared_template,
    post_notifications_content_compliance_cleared_template_apply,
    post_notifications_content_compliance_cleared_template_reorder,
    post_notifications_content_compliance_cleared_templates_import,
    post_notifications_content_compliance_cleared_templates_shared,
    post_notifications_content_compliance_cleared_templates_shared_audit_export_async,
    post_notifications_content_compliance_sync, post_notifications_preferences,
    post_notifications_preferences_apply_template, post_notifications_preferences_import,
    post_notifications_preferences_reset,
};
pub use storage::{
    notification_created_envelope, notification_updated_envelope, record_notification,
};
pub use types::{
    ApplyContentComplianceClearedTemplateBody, ApplyContentComplianceClearedTemplateResponse,
    ApplyNotificationPreferencesTemplateBody, ContentComplianceClearedTemplateAuditItem,
    ContentComplianceClearedTemplateItem, ContentComplianceClearedTemplatePolicy,
    DeleteContentComplianceClearedTemplateBody, DeleteContentComplianceClearedTemplateResponse,
    DeleteNotificationsBody, DeleteNotificationsResponse,
    ExportContentComplianceClearedTemplatesResponse,
    ExportWorkspaceContentComplianceClearedTemplateAuditQuery,
    ExportWorkspaceContentComplianceClearedTemplateAuditResponse,
    ImportContentComplianceClearedTemplatesBody, ImportContentComplianceClearedTemplatesResponse,
    ImportNotificationPreferencesBody, ListContentComplianceClearedTemplatesResponse,
    ListNotificationsEnvelope, ListWorkspaceContentComplianceClearedTemplateAuditExportsQuery,
    ListWorkspaceContentComplianceClearedTemplateAuditExportsResponse,
    ListWorkspaceContentComplianceClearedTemplateAuditQuery,
    ListWorkspaceContentComplianceClearedTemplateAuditResponse,
    ListWorkspaceContentComplianceClearedTemplatesResponse, MarkAllNotificationsReadResponse,
    MarkNotificationsReadBody, MarkNotificationsReadEnvelope, NotificationPreferences,
    NotificationPreferencesAuditMeta, NotificationPreferencesEnvelope, NotificationRecord,
    NotificationRecordPayload, ReorderContentComplianceClearedTemplatesBody,
    ReorderContentComplianceClearedTemplatesResponse, SyncContentComplianceAlertsBody,
    SyncContentComplianceAlertsResponse, UpsertContentComplianceClearedTemplateBody,
    UpsertContentComplianceClearedTemplateResponse, WorkspaceSharedAuditExportEnqueueBody,
    WorkspaceSharedAuditExportJobRecord,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings/notifications", get(get_notifications))
        .route(
            "/api/v1/settings/notifications/mark-read",
            axum::routing::post(mark_notifications_read),
        )
        .route(
            "/api/v1/settings/notifications/mark-all-read",
            axum::routing::post(mark_all_notifications_read),
        )
        .route(
            "/api/v1/settings/notifications/delete",
            axum::routing::post(delete_notifications),
        )
        .route(
            "/api/v1/settings/notifications/delete-read",
            axum::routing::post(delete_read_notifications),
        )
        .route(
            "/api/v1/settings/notifications/preferences",
            get(get_notifications_preferences).post(post_notifications_preferences),
        )
        .route(
            "/api/v1/settings/notifications/preferences/export",
            get(get_notifications_preferences_export),
        )
        .route(
            "/api/v1/settings/notifications/preferences/import",
            axum::routing::post(post_notifications_preferences_import),
        )
        .route(
            "/api/v1/settings/notifications/preferences/reset",
            axum::routing::post(post_notifications_preferences_reset),
        )
        .route(
            "/api/v1/settings/notifications/preferences/apply-template",
            axum::routing::post(post_notifications_preferences_apply_template),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/sync",
            axum::routing::post(post_notifications_content_compliance_sync),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates",
            get(get_notifications_content_compliance_cleared_templates)
                .post(post_notifications_content_compliance_cleared_template)
                .delete(delete_notifications_content_compliance_cleared_template),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/export",
            get(get_notifications_content_compliance_cleared_templates_export),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/import",
            axum::routing::post(post_notifications_content_compliance_cleared_templates_import),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/apply",
            axum::routing::post(post_notifications_content_compliance_cleared_template_apply),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/reorder",
            axum::routing::post(post_notifications_content_compliance_cleared_template_reorder),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/shared",
            get(get_notifications_content_compliance_cleared_templates_shared)
                .post(post_notifications_content_compliance_cleared_templates_shared)
                .delete(delete_notifications_content_compliance_cleared_templates_shared),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit",
            get(get_notifications_content_compliance_cleared_templates_shared_audit),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export",
            get(get_notifications_content_compliance_cleared_templates_shared_audit_export),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async",
            axum::routing::post(
                post_notifications_content_compliance_cleared_templates_shared_audit_export_async,
            ),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}",
            get(get_notifications_content_compliance_cleared_templates_shared_audit_export_job),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}/file",
            get(get_notifications_content_compliance_cleared_templates_shared_audit_export_job_file),
        )
        .route(
            "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/exports",
            get(get_notifications_content_compliance_cleared_templates_shared_audit_exports),
        )
}
