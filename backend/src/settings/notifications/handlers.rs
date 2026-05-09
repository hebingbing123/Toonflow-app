use axum::{
    extract::{Json, Query, State},
    http::HeaderMap,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::storage::{
    list_notifications, mark_all_notifications_read as mark_all_notifications_read_storage,
    mark_notifications_read_state, unread_notification_count,
};
use super::types::{
    ListNotificationsEnvelope, ListNotificationsQuery, MarkAllNotificationsReadResponse,
    MarkNotificationsReadBody, MarkNotificationsReadEnvelope,
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
