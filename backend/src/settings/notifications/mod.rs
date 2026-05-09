use axum::{routing::get, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_delete_notifications, __path_delete_read_notifications, __path_get_notifications,
    __path_get_notifications_preferences, __path_get_notifications_preferences_export,
    __path_mark_all_notifications_read, __path_mark_notifications_read,
    __path_post_notifications_preferences, __path_post_notifications_preferences_apply_template,
    __path_post_notifications_preferences_import, __path_post_notifications_preferences_reset,
};
pub(crate) use handlers::{
    delete_notifications, delete_read_notifications, get_notifications,
    get_notifications_preferences, get_notifications_preferences_export,
    mark_all_notifications_read, mark_notifications_read, post_notifications_preferences,
    post_notifications_preferences_apply_template, post_notifications_preferences_import,
    post_notifications_preferences_reset,
};
pub use storage::{
    notification_created_envelope, notification_updated_envelope, record_notification,
};
pub use types::{
    ApplyNotificationPreferencesTemplateBody, DeleteNotificationsBody, DeleteNotificationsResponse,
    ImportNotificationPreferencesBody, ListNotificationsEnvelope, MarkAllNotificationsReadResponse,
    MarkNotificationsReadBody, MarkNotificationsReadEnvelope, NotificationPreferences,
    NotificationPreferencesAuditMeta, NotificationPreferencesEnvelope, NotificationRecord,
    NotificationRecordPayload,
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
}
