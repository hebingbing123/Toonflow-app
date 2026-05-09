use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::WsNotifyHub;

use super::types::{
    ListNotificationsEnvelope, ListNotificationsQuery, NotificationRecord,
    NotificationRecordPayload,
};

pub async fn record_notification(
    pool: &PgPool,
    notify: Option<&WsNotifyHub>,
    entry: NotificationRecordPayload,
) -> Result<NotificationRecord, ApiError> {
    let row: NotificationRecord = sqlx::query_as(
        r#"
        INSERT INTO public.app_notification (
          user_id,
          workspace_id,
          project_id,
          project_numeric_id,
          job_id,
          notification_type,
          title,
          message,
          link_path,
          payload,
          file_path,
          changed_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING
          id,
          user_id,
          workspace_id,
          project_id,
          project_numeric_id,
          job_id,
          notification_type,
          title,
          message,
          link_path,
          payload,
          file_path,
          changed_at,
          read_at,
          created_at,
          updated_at
        "#,
    )
    .bind(entry.user_id)
    .bind(entry.workspace_id)
    .bind(entry.project_id)
    .bind(entry.project_numeric_id)
    .bind(entry.job_id)
    .bind(entry.notification_type)
    .bind(entry.title)
    .bind(entry.message)
    .bind(entry.link_path)
    .bind(entry.payload)
    .bind(entry.file_path)
    .bind(entry.changed_at)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(hub) = notify {
        hub.broadcast_to_user(row.user_id, notification_created_envelope(&row))
            .await;
    }

    Ok(row)
}

pub async fn list_notifications(
    pool: &PgPool,
    user_id: Uuid,
    query: &ListNotificationsQuery,
) -> Result<ListNotificationsEnvelope, ApiError> {
    let page_size = query.limit.unwrap_or(50).clamp(1, 200);
    let fetch_limit = page_size.saturating_add(1);
    let unread_only = query.unread_only.unwrap_or(false);
    let notification_type = normalize_optional_string(query.notification_type.clone());
    let search = normalize_optional_string(query.query.clone());

    let rows: Vec<NotificationRecord> = sqlx::query_as(
        r#"
        SELECT
          id,
          user_id,
          workspace_id,
          project_id,
          project_numeric_id,
          job_id,
          notification_type,
          title,
          message,
          link_path,
          payload,
          file_path,
          changed_at,
          read_at,
          created_at,
          updated_at
        FROM public.app_notification
        WHERE user_id = $1
          AND ($2::text IS NULL OR notification_type = $2)
          AND (NOT $3::bool OR read_at IS NULL)
          AND ($4::bigint IS NULL OR id < $4)
          AND (
            $5::text IS NULL
            OR title ILIKE '%' || $5 || '%'
            OR message ILIKE '%' || $5 || '%'
            OR COALESCE(link_path, '') ILIKE '%' || $5 || '%'
            OR payload::text ILIKE '%' || $5 || '%'
          )
        ORDER BY created_at DESC, id DESC
        LIMIT $6
        "#,
    )
    .bind(user_id)
    .bind(notification_type)
    .bind(unread_only)
    .bind(query.before_id)
    .bind(search)
    .bind(fetch_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let unread_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_notification
        WHERE user_id = $1
          AND read_at IS NULL
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut items = rows;
    let has_more = (items.len() as i64) > page_size;
    if has_more {
        items.truncate(page_size as usize);
    }
    let next_before_id = items.last().map(|row| row.id);

    Ok(ListNotificationsEnvelope {
        items,
        unread_count,
        has_more,
        next_before_id,
    })
}

pub async fn mark_notifications_read_state(
    pool: &PgPool,
    notify: &WsNotifyHub,
    user_id: Uuid,
    ids: &[i64],
    read: bool,
) -> Result<Vec<NotificationRecord>, ApiError> {
    let rows: Vec<NotificationRecord> = sqlx::query_as(
        r#"
        UPDATE public.app_notification
        SET
          read_at = CASE
            WHEN $3::bool THEN COALESCE(read_at, NOW())
            ELSE NULL
          END,
          updated_at = NOW()
        WHERE user_id = $1
          AND id = ANY($2)
        RETURNING
          id,
          user_id,
          workspace_id,
          project_id,
          project_numeric_id,
          job_id,
          notification_type,
          title,
          message,
          link_path,
          payload,
          file_path,
          changed_at,
          read_at,
          created_at,
          updated_at
        ORDER BY id DESC
        "#,
    )
    .bind(user_id)
    .bind(ids)
    .bind(read)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for row in &rows {
        notify
            .broadcast_to_user(user_id, notification_updated_envelope(row))
            .await;
    }

    Ok(rows)
}

pub async fn mark_all_notifications_read(
    pool: &PgPool,
    notify: &WsNotifyHub,
    user_id: Uuid,
) -> Result<i64, ApiError> {
    let rows: Vec<NotificationRecord> = sqlx::query_as(
        r#"
        UPDATE public.app_notification
        SET read_at = COALESCE(read_at, NOW()), updated_at = NOW()
        WHERE user_id = $1
          AND read_at IS NULL
        RETURNING
          id,
          user_id,
          workspace_id,
          project_id,
          project_numeric_id,
          job_id,
          notification_type,
          title,
          message,
          link_path,
          payload,
          file_path,
          changed_at,
          read_at,
          created_at,
          updated_at
        ORDER BY id DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for row in &rows {
        notify
            .broadcast_to_user(user_id, notification_updated_envelope(row))
            .await;
    }

    Ok(rows.len() as i64)
}

pub async fn unread_notification_count(pool: &PgPool, user_id: Uuid) -> Result<i64, ApiError> {
    sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_notification
        WHERE user_id = $1
          AND read_at IS NULL
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub fn notification_created_envelope(row: &NotificationRecord) -> String {
    serde_json::to_string(&json!({
        "type": "settings.notification.created",
        "schema_version": 1,
        "payload": row,
    }))
    .expect("notification envelope should serialize")
}

pub fn notification_updated_envelope(row: &NotificationRecord) -> String {
    serde_json::to_string(&json!({
        "type": "settings.notification.updated",
        "schema_version": 1,
        "payload": row,
    }))
    .expect("notification envelope should serialize")
}

fn normalize_optional_string(raw: Option<String>) -> Option<String> {
    raw.and_then(|value| {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_owned())
        }
    })
}
