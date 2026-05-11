use serde_json::json;
use sqlx::PgPool;
use std::collections::HashMap;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::WsNotifyHub;

use super::content_compliance_sync_pure::{
    normalize_compliance_stage, normalize_compliance_template_id,
    normalize_template_ids_preserve_order,
};
use super::types::{
    ContentComplianceClearedTemplateItem, ListNotificationsEnvelope, ListNotificationsQuery,
    NotificationPreferences, NotificationPreferencesAuditMeta, NotificationPreferencesEnvelope,
    NotificationRecord, NotificationRecordPayload,
};

fn default_content_compliance_cleared_throttle_minutes() -> i64 {
    std::env::var("TOONFLOW_COMPLIANCE_CLEARED_THROTTLE_MINUTES")
        .ok()
        .and_then(|v| v.trim().parse::<i64>().ok())
        .filter(|v| *v > 0)
        .unwrap_or(30)
}

pub async fn record_notification(
    pool: &PgPool,
    notify: Option<&WsNotifyHub>,
    entry: NotificationRecordPayload,
) -> Result<Option<NotificationRecord>, ApiError> {
    if is_notification_muted(pool, &entry).await? {
        return Ok(None);
    }

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

    Ok(Some(row))
}

pub async fn list_notifications(
    pool: &PgPool,
    user_id: Uuid,
    query: &ListNotificationsQuery,
) -> Result<ListNotificationsEnvelope, ApiError> {
    let page_size = query.limit.unwrap_or(50).clamp(1, 200);
    let fetch_limit = page_size.saturating_add(1);
    let unread_only = query.unread_only.unwrap_or(false);
    let include_muted = query.include_muted.unwrap_or(false);
    let notification_type = normalize_optional_string(query.notification_type.clone());
    let search = normalize_optional_string(query.query.clone());
    let prefs = get_notification_preferences(pool, user_id).await?;
    let muted_types = if include_muted {
        Vec::new()
    } else {
        prefs
            .muted_notification_types
            .iter()
            .map(|item| item.trim().to_owned())
            .filter(|item| !item.is_empty())
            .collect::<Vec<_>>()
    };
    let muted_workspace_ids = if include_muted {
        Vec::new()
    } else {
        prefs.muted_workspace_ids.clone()
    };
    let muted_project_ids = if include_muted {
        Vec::new()
    } else {
        prefs.muted_project_ids.clone()
    };
    let deliver_critical_even_muted = prefs.deliver_critical_even_muted;

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
            ($10::bool AND COALESCE(payload->>'severity', '') = 'critical')
            OR
            COALESCE(array_length($7::text[], 1), 0) = 0
            OR NOT (notification_type = ANY($7))
          )
          AND (
            ($10::bool AND COALESCE(payload->>'severity', '') = 'critical')
            OR
            COALESCE(array_length($8::uuid[], 1), 0) = 0
            OR workspace_id IS NULL
            OR NOT (workspace_id = ANY($8))
          )
          AND (
            ($10::bool AND COALESCE(payload->>'severity', '') = 'critical')
            OR
            COALESCE(array_length($9::uuid[], 1), 0) = 0
            OR project_id IS NULL
            OR NOT (project_id = ANY($9))
          )
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
    .bind(&muted_types)
    .bind(muted_workspace_ids.clone())
    .bind(muted_project_ids.clone())
    .bind(deliver_critical_even_muted)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let unread_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_notification
        WHERE user_id = $1
          AND read_at IS NULL
          AND (
            ($5::bool AND COALESCE(payload->>'severity', '') = 'critical')
            OR
            COALESCE(array_length($2::text[], 1), 0) = 0
            OR NOT (notification_type = ANY($2))
          )
          AND (
            ($5::bool AND COALESCE(payload->>'severity', '') = 'critical')
            OR
            COALESCE(array_length($3::uuid[], 1), 0) = 0
            OR workspace_id IS NULL
            OR NOT (workspace_id = ANY($3))
          )
          AND (
            ($5::bool AND COALESCE(payload->>'severity', '') = 'critical')
            OR
            COALESCE(array_length($4::uuid[], 1), 0) = 0
            OR project_id IS NULL
            OR NOT (project_id = ANY($4))
          )
        "#,
    )
    .bind(user_id)
    .bind(muted_types)
    .bind(muted_workspace_ids)
    .bind(muted_project_ids)
    .bind(deliver_critical_even_muted)
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

pub async fn delete_notifications(
    pool: &PgPool,
    user_id: Uuid,
    ids: &[i64],
) -> Result<i64, ApiError> {
    let deleted: i64 = sqlx::query_scalar(
        r#"
        WITH deleted_rows AS (
          DELETE FROM public.app_notification
          WHERE user_id = $1
            AND id = ANY($2)
          RETURNING id
        )
        SELECT COUNT(*)::bigint
        FROM deleted_rows
        "#,
    )
    .bind(user_id)
    .bind(ids)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(deleted)
}

pub async fn delete_read_notifications(pool: &PgPool, user_id: Uuid) -> Result<i64, ApiError> {
    let deleted: i64 = sqlx::query_scalar(
        r#"
        WITH deleted_rows AS (
          DELETE FROM public.app_notification
          WHERE user_id = $1
            AND read_at IS NOT NULL
          RETURNING id
        )
        SELECT COUNT(*)::bigint
        FROM deleted_rows
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(deleted)
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

pub async fn get_notification_preferences(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<NotificationPreferences, ApiError> {
    let raw: Option<sqlx::types::Json<NotificationPreferences>> = sqlx::query_scalar(
        r#"
        SELECT notification_preferences
        FROM public.app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(raw.map_or_else(NotificationPreferences::default, |v| v.0))
}

pub async fn get_notification_preferences_envelope(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<NotificationPreferencesEnvelope, ApiError> {
    type PreferencesRow = (
        Option<sqlx::types::Json<NotificationPreferences>>,
        Option<sqlx::types::Json<serde_json::Value>>,
        Option<chrono::DateTime<chrono::Utc>>,
    );

    let row: Option<PreferencesRow> = sqlx::query_as(
        r#"
        SELECT notification_preferences, notification_preferences_meta, updated_at
        FROM public.app_user_profile
        WHERE user_id = $1
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some((prefs_raw, meta_raw, updated_at)) = row else {
        return Ok(NotificationPreferencesEnvelope {
            preferences: NotificationPreferences::default(),
            audit: NotificationPreferencesAuditMeta::default(),
        });
    };
    let mut audit = NotificationPreferencesAuditMeta {
        updated_at,
        ..Default::default()
    };
    if let Some(meta) = meta_raw.and_then(|v| v.0.as_object().cloned()) {
        if let Some(updated_by) = meta.get("updatedBy").and_then(|v| v.as_str()) {
            let trimmed = updated_by.trim();
            if !trimmed.is_empty() {
                audit.updated_by = trimmed.to_string();
            }
        }
        if let Some(source) = meta.get("source").and_then(|v| v.as_str()) {
            let trimmed = source.trim();
            if !trimmed.is_empty() {
                audit.source = trimmed.to_string();
            }
        }
    }
    Ok(NotificationPreferencesEnvelope {
        preferences: prefs_raw.map_or_else(NotificationPreferences::default, |v| v.0),
        audit,
    })
}

pub async fn upsert_notification_preferences(
    pool: &PgPool,
    user_id: Uuid,
    prefs: &NotificationPreferences,
    source: &str,
) -> Result<NotificationPreferences, ApiError> {
    let cleaned = NotificationPreferences {
        muted_notification_types: prefs
            .muted_notification_types
            .iter()
            .map(|item| item.trim().to_owned())
            .filter(|item| !item.is_empty())
            .collect::<std::collections::BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>(),
        muted_workspace_ids: prefs
            .muted_workspace_ids
            .iter()
            .copied()
            .collect::<std::collections::BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>(),
        muted_project_ids: prefs
            .muted_project_ids
            .iter()
            .copied()
            .collect::<std::collections::BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>(),
        deliver_critical_even_muted: prefs.deliver_critical_even_muted,
        content_compliance_cleared_throttle_minutes: prefs
            .content_compliance_cleared_throttle_minutes
            .clamp(1, 1440),
        content_compliance_cleared_stage_throttle_minutes: prefs
            .content_compliance_cleared_stage_throttle_minutes
            .iter()
            .filter_map(|(stage, minutes)| {
                let normalized = normalize_compliance_stage(stage);
                if normalized.is_empty() {
                    return None;
                }
                Some((normalized, (*minutes).clamp(1, 1440)))
            })
            .collect::<std::collections::BTreeMap<_, _>>()
            .into_iter()
            .collect::<HashMap<_, _>>(),
        content_compliance_cleared_templates: prefs
            .content_compliance_cleared_templates
            .iter()
            .filter_map(|tpl| {
                let id = normalize_compliance_template_id(&tpl.id);
                let label = tpl.label.trim().to_string();
                if id.is_empty() || label.is_empty() {
                    return None;
                }
                let description = tpl.description.trim().to_string();
                let global_minutes = tpl.policy.global_minutes.clamp(1, 1440);
                let stage_minutes = tpl
                    .policy
                    .stage_minutes
                    .iter()
                    .filter_map(|(stage, minutes)| {
                        let normalized_stage = normalize_compliance_stage(stage);
                        if normalized_stage.is_empty() {
                            return None;
                        }
                        Some((normalized_stage, (*minutes).clamp(1, 1440)))
                    })
                    .collect::<std::collections::BTreeMap<_, _>>()
                    .into_iter()
                    .collect::<HashMap<_, _>>();
                Some((
                    id.clone(),
                    ContentComplianceClearedTemplateItem {
                        id,
                        label,
                        description,
                        policy: super::types::ContentComplianceClearedTemplatePolicy {
                            global_minutes,
                            stage_minutes,
                        },
                        kind: "custom".to_string(),
                        can_edit: true,
                        can_delete: true,
                    },
                ))
            })
            .collect::<std::collections::BTreeMap<_, _>>()
            .into_values()
            .collect::<Vec<_>>(),
        content_compliance_cleared_template_order: normalize_template_ids_preserve_order(
            &prefs.content_compliance_cleared_template_order,
        ),
        content_compliance_cleared_recent_template_ids: normalize_template_ids_preserve_order(
            &prefs.content_compliance_cleared_recent_template_ids,
        ),
    };
    let saved: sqlx::types::Json<NotificationPreferences> = sqlx::query_scalar(
        r#"
        INSERT INTO public.app_user_profile (user_id, notification_preferences, notification_preferences_meta)
        VALUES ($1, $2, $3)
        ON CONFLICT (user_id) DO UPDATE
        SET notification_preferences = EXCLUDED.notification_preferences,
            notification_preferences_meta = EXCLUDED.notification_preferences_meta,
            updated_at = NOW()
        RETURNING notification_preferences
        "#,
    )
    .bind(user_id)
    .bind(sqlx::types::Json(cleaned))
    .bind(sqlx::types::Json(json!({
        "updatedBy": "self",
        "source": source.trim(),
    })))
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(saved.0)
}

pub async fn reset_notification_preferences(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<NotificationPreferences, ApiError> {
    upsert_notification_preferences(pool, user_id, &NotificationPreferences::default(), "reset")
        .await
}

pub async fn apply_notification_preferences_template(
    pool: &PgPool,
    user_id: Uuid,
    template_raw: &str,
) -> Result<NotificationPreferences, ApiError> {
    let template = template_raw.trim().to_ascii_lowercase();
    if template.is_empty() {
        return Err(ApiError::BadRequest("template must not be empty".into()));
    }
    let known_types: Vec<String> = sqlx::query_scalar(
        r#"
        SELECT DISTINCT notification_type
        FROM public.app_notification
        WHERE user_id = $1
          AND notification_type <> ''
        ORDER BY notification_type ASC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    const INCIDENT_TYPES: &[&str] = &["platform.status", "job_failed", "job_cancelled"];
    let prefs = match template.as_str() {
        "default" => NotificationPreferences::default(),
        "quiet" => NotificationPreferences {
            muted_notification_types: known_types,
            muted_workspace_ids: Vec::new(),
            muted_project_ids: Vec::new(),
            deliver_critical_even_muted: true,
            content_compliance_cleared_throttle_minutes:
                default_content_compliance_cleared_throttle_minutes(),
            content_compliance_cleared_stage_throttle_minutes: HashMap::new(),
            content_compliance_cleared_templates: Vec::new(),
            content_compliance_cleared_template_order: Vec::new(),
            content_compliance_cleared_recent_template_ids: Vec::new(),
        },
        "incident" => NotificationPreferences {
            muted_notification_types: known_types
                .into_iter()
                .filter(|item| !INCIDENT_TYPES.contains(&item.as_str()))
                .collect::<Vec<_>>(),
            muted_workspace_ids: Vec::new(),
            muted_project_ids: Vec::new(),
            deliver_critical_even_muted: true,
            content_compliance_cleared_throttle_minutes:
                default_content_compliance_cleared_throttle_minutes(),
            content_compliance_cleared_stage_throttle_minutes: HashMap::new(),
            content_compliance_cleared_templates: Vec::new(),
            content_compliance_cleared_template_order: Vec::new(),
            content_compliance_cleared_recent_template_ids: Vec::new(),
        },
        _ => {
            return Err(ApiError::BadRequest(
                "template must be one of: default, quiet, incident".into(),
            ))
        }
    };
    upsert_notification_preferences(pool, user_id, &prefs, &format!("template:{template}")).await
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

async fn is_notification_muted(
    pool: &PgPool,
    entry: &NotificationRecordPayload,
) -> Result<bool, ApiError> {
    let prefs = get_notification_preferences(pool, entry.user_id).await?;
    if prefs.deliver_critical_even_muted
        && entry
            .payload
            .get("severity")
            .and_then(|value| value.as_str())
            .map(|value| value.trim().eq_ignore_ascii_case("critical"))
            .unwrap_or(false)
    {
        return Ok(false);
    }
    if prefs
        .muted_notification_types
        .iter()
        .any(|item| item.trim() == entry.notification_type)
    {
        return Ok(true);
    }
    if let Some(workspace_id) = entry.workspace_id {
        if prefs.muted_workspace_ids.contains(&workspace_id) {
            return Ok(true);
        }
    }
    if let Some(project_id) = entry.project_id {
        if prefs.muted_project_ids.contains(&project_id) {
            return Ok(true);
        }
    }
    Ok(false)
}
