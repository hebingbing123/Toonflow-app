use axum::{
    extract::{Json, Query, State},
    http::HeaderMap,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::storage::{
    apply_notification_preferences_template, delete_notifications as delete_notifications_storage,
    delete_read_notifications as delete_read_notifications_storage, get_notification_preferences,
    get_notification_preferences_envelope, list_notifications,
    mark_all_notifications_read as mark_all_notifications_read_storage,
    mark_notifications_read_state, reset_notification_preferences, unread_notification_count,
    upsert_notification_preferences,
};
use super::types::{
    ApplyNotificationPreferencesTemplateBody, DeleteNotificationsBody, DeleteNotificationsResponse,
    ImportNotificationPreferencesBody, ListNotificationsEnvelope, ListNotificationsQuery,
    MarkAllNotificationsReadResponse, MarkNotificationsReadBody, MarkNotificationsReadEnvelope,
    NotificationPreferences, NotificationPreferencesEnvelope,
};

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications",
    operation_id = "getNotificationsV1",
    tag = "settings",
    params(ListNotificationsQuery),
    responses(
        (status = 200, description = "OK", body = ListNotificationsEnvelope),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListNotificationsQuery>,
) -> Result<Json<ListNotificationsEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(list_notifications(pool, uid, &query).await?))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/mark-read",
    operation_id = "markNotificationsReadV1",
    tag = "settings",
    request_body = MarkNotificationsReadBody,
    responses(
        (status = 200, description = "OK", body = MarkNotificationsReadEnvelope),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn mark_notifications_read(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<MarkNotificationsReadBody>,
) -> Result<Json<MarkNotificationsReadEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("ids must not be empty".into()));
    }
    let read = body.read.unwrap_or(true);
    let items = mark_notifications_read_state(pool, &state.notify, uid, &body.ids, read).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(MarkNotificationsReadEnvelope {
        items,
        unread_count,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/mark-all-read",
    operation_id = "markAllNotificationsReadV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = MarkAllNotificationsReadResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn mark_all_notifications_read(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MarkAllNotificationsReadResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let updated_count = mark_all_notifications_read_storage(pool, &state.notify, uid).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(MarkAllNotificationsReadResponse {
        updated_count,
        unread_count,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/delete",
    operation_id = "deleteNotificationsV1",
    tag = "settings",
    request_body = DeleteNotificationsBody,
    responses(
        (status = 200, description = "OK", body = DeleteNotificationsResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_notifications(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteNotificationsBody>,
) -> Result<Json<DeleteNotificationsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("ids must not be empty".into()));
    }
    let deleted_count = delete_notifications_storage(pool, uid, &body.ids).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(DeleteNotificationsResponse {
        deleted_count,
        unread_count,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/delete-read",
    operation_id = "deleteReadNotificationsV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = DeleteNotificationsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_read_notifications(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<DeleteNotificationsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let deleted_count = delete_read_notifications_storage(pool, uid).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(DeleteNotificationsResponse {
        deleted_count,
        unread_count,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/preferences",
    operation_id = "getNotificationPreferencesV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(get_notification_preferences(pool, uid).await?))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/preferences/export",
    operation_id = "getNotificationPreferencesExportV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = NotificationPreferencesEnvelope),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_preferences_export(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<NotificationPreferencesEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        get_notification_preferences_envelope(pool, uid).await?,
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences",
    operation_id = "postNotificationPreferencesV1",
    tag = "settings",
    request_body = NotificationPreferences,
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<NotificationPreferences>,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        upsert_notification_preferences(pool, uid, &body, "manual").await?,
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences/import",
    operation_id = "postNotificationPreferencesImportV1",
    tag = "settings",
    request_body = ImportNotificationPreferencesBody,
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences_import(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ImportNotificationPreferencesBody>,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        upsert_notification_preferences(pool, uid, &body.envelope.preferences, "import").await?,
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences/reset",
    operation_id = "postNotificationPreferencesResetV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences_reset(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(reset_notification_preferences(pool, uid).await?))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences/apply-template",
    operation_id = "postNotificationPreferencesApplyTemplateV1",
    tag = "settings",
    request_body = ApplyNotificationPreferencesTemplateBody,
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences_apply_template(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ApplyNotificationPreferencesTemplateBody>,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        apply_notification_preferences_template(pool, uid, &body.template).await?,
    ))
}
