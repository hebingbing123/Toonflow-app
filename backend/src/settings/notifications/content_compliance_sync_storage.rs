//! Postgres + WebSocket 路径：将合规队列告警同步到 `app_notification`（与纯函数 [`super::content_compliance_sync_pure`] 配套）。

use serde_json::{json, Value};
use sqlx::PgPool;
use std::collections::{HashMap, HashSet};
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::WsNotifyHub;

use super::content_compliance_sync_pure::{
    build_content_compliance_alert_payload, content_compliance_alert_unchanged,
    normalize_compliance_stage,
};
use super::storage::{
    get_notification_preferences, notification_created_envelope, notification_updated_envelope,
};
use super::types::{ContentComplianceAlertSyncItem, NotificationRecord};

pub async fn sync_content_compliance_alert_notifications(
    pool: &PgPool,
    notify: &WsNotifyHub,
    user_id: Uuid,
    alerts: &[ContentComplianceAlertSyncItem],
) -> Result<i64, ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let existing_rows: Vec<NotificationRecord> = sqlx::query_as(
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
          AND notification_type = 'content_compliance_alert'
        "#,
    )
    .bind(user_id)
    .fetch_all(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut existing_by_stage: HashMap<String, NotificationRecord> = HashMap::new();
    for row in existing_rows {
        if let Some(stage) = row
            .payload
            .get("stage")
            .and_then(Value::as_str)
            .map(str::to_string)
        {
            existing_by_stage.insert(stage, row);
        }
    }

    let mut synced = 0_i64;
    let now = chrono::Utc::now();
    let mut active_stages = HashSet::<String>::new();
    for alert in alerts {
        let stage = alert.stage.trim();
        if stage.is_empty() {
            continue;
        }
        active_stages.insert(stage.to_string());
        let previous = existing_by_stage.get(stage);
        let unchanged = previous.is_some_and(|row| {
            let payload_level = row
                .payload
                .get("level")
                .and_then(Value::as_str)
                .unwrap_or("");
            let payload_count = row
                .payload
                .get("count")
                .and_then(Value::as_i64)
                .unwrap_or(0);
            content_compliance_alert_unchanged(
                row.title.as_str(),
                row.message.as_str(),
                &row.link_path,
                payload_level,
                payload_count,
                alert,
            )
        });
        let payload =
            build_content_compliance_alert_payload(stage, alert.level.as_str(), alert.count);
        if let Some(previous_row) = previous {
            if unchanged {
                synced += 1;
                continue;
            }
            let row: NotificationRecord = sqlx::query_as(
                r#"
                UPDATE public.app_notification
                SET
                  title = $2,
                  message = $3,
                  link_path = $4,
                  payload = $5,
                  changed_at = $6,
                  read_at = NULL,
                  updated_at = NOW()
                WHERE id = $1
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
            .bind(previous_row.id)
            .bind(alert.title.trim())
            .bind(alert.message.trim())
            .bind(
                alert
                    .link_path
                    .as_ref()
                    .map(|v| v.trim().to_string())
                    .filter(|v| !v.is_empty()),
            )
            .bind(payload)
            .bind(Some(now))
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            notify
                .broadcast_to_user(user_id, notification_updated_envelope(&row))
                .await;
            synced += 1;
            continue;
        }
        let row: NotificationRecord = sqlx::query_as(
            r#"
            INSERT INTO public.app_notification (
              user_id,
              notification_type,
              title,
              message,
              link_path,
              payload,
              changed_at,
              read_at
            )
            VALUES ($1, 'content_compliance_alert', $2, $3, $4, $5, $6, NULL)
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
        .bind(user_id)
        .bind(alert.title.trim())
        .bind(alert.message.trim())
        .bind(
            alert
                .link_path
                .as_ref()
                .map(|v| v.trim().to_string())
                .filter(|v| !v.is_empty()),
        )
        .bind(payload)
        .bind(Some(now))
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        notify
            .broadcast_to_user(user_id, notification_created_envelope(&row))
            .await;
        synced += 1;
    }

    let stale_stage_rows = existing_by_stage
        .into_iter()
        .filter(|(stage, _)| !active_stages.contains(stage))
        .map(|(_, row)| row)
        .collect::<Vec<_>>();

    sqlx::query(
        r#"
        DELETE FROM public.app_notification
        WHERE user_id = $1
          AND notification_type = 'content_compliance_alert'
          AND NOT (COALESCE(payload->>'stage', '') = ANY($2))
        "#,
    )
    .bind(user_id)
    .bind(active_stages.iter().cloned().collect::<Vec<_>>())
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let user_prefs = get_notification_preferences(pool, user_id).await?;
    let global_cleared_throttle_minutes = user_prefs
        .content_compliance_cleared_throttle_minutes
        .clamp(1, 1440);
    for stale in stale_stage_rows {
        let stage = stale
            .payload
            .get("stage")
            .and_then(Value::as_str)
            .unwrap_or("unknown")
            .trim()
            .to_string();
        let normalized_stage = normalize_compliance_stage(&stage);
        let cleared_throttle_minutes = user_prefs
            .content_compliance_cleared_stage_throttle_minutes
            .get(&normalized_stage)
            .copied()
            .unwrap_or(global_cleared_throttle_minutes)
            .clamp(1, 1440);
        let recent_cleared_exists: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
              SELECT 1
              FROM public.app_notification
              WHERE user_id = $1
                AND notification_type = 'content_compliance_alert_cleared'
                AND COALESCE(payload->>'stage', '') = $2
                AND created_at >= NOW() - make_interval(mins => $3)
            )
            "#,
        )
        .bind(user_id)
        .bind(&stage)
        .bind(cleared_throttle_minutes)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if recent_cleared_exists {
            continue;
        }
        let title = format!("内容合规告警已清除：{stage}");
        let message = format!("告警分层 {stage} 已从当前开放队列中清除。");
        let cleared: NotificationRecord = sqlx::query_as(
            r#"
            INSERT INTO public.app_notification (
              user_id,
              notification_type,
              title,
              message,
              link_path,
              payload,
              changed_at,
              read_at
            )
            VALUES ($1, 'content_compliance_alert_cleared', $2, $3, $4, $5, $6, NULL)
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
        .bind(user_id)
        .bind(title)
        .bind(message)
        .bind(format!(
            "/product/content-compliance?escalationStage={stage}"
        ))
        .bind(json!({
            "source": "content_compliance",
            "stage": stage,
            "status": "cleared",
        }))
        .bind(Some(now))
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        notify
            .broadcast_to_user(user_id, notification_created_envelope(&cleared))
            .await;
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(synced)
}
