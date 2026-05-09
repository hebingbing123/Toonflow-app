use axum::{routing::get, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_get_notifications, __path_mark_all_notifications_read, __path_mark_notifications_read,
};
pub(crate) use handlers::{
    get_notifications, mark_all_notifications_read, mark_notifications_read,
};
pub use storage::{
    notification_created_envelope, notification_updated_envelope, record_notification,
};
pub use types::{
    ListNotificationsEnvelope, MarkAllNotificationsReadResponse, MarkNotificationsReadBody,
    MarkNotificationsReadEnvelope, NotificationRecord, NotificationRecordPayload,
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
}
