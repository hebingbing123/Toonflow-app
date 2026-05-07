//! Job operations for publish store.

use serde_json::{json, Value};
use sqlx::types::Json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::publish::types::{
    CreatePublishJobBody, PublishAttemptAuditRow, PublishJobRow, PublishPerformanceAlertRow,
    PublishTargetRow,
};
pub(crate) async fn insert_publish_job(
    pool: &PgPool,
    project_id: Uuid,
    draft_id: Uuid,
    owner_user_id: Uuid,
    body: &CreatePublishJobBody,
) -> Result<PublishJobRow, ApiError> {
    sqlx::query_as::<_, PublishJobRow>(
        r#"
        INSERT INTO app_publish_job (project_id, draft_id, owner_user_id, status, payload)
        VALUES ($1, $2, $3, 'queued', $4)
        RETURNING id, project_id, draft_id, owner_user_id, status, semi_auto_ack_at,
                  payload, error_message, error_details, claimed_by, created_at, updated_at
        "#,
    )
    .bind(project_id)
    .bind(draft_id)
    .bind(owner_user_id)
    .bind(Json(body.payload.clone()))
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn list_jobs(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Vec<PublishJobRow>, ApiError> {
    sqlx::query_as::<_, PublishJobRow>(
        r#"
        SELECT id, project_id, draft_id, owner_user_id, status, semi_auto_ack_at,
               payload, error_message, error_details, claimed_by, created_at, updated_at
        FROM app_publish_job
        WHERE project_id = $1
        ORDER BY created_at DESC
        LIMIT 100
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) struct ListAttemptAuditFilter<'a> {
    pub(crate) draft_id: Option<Uuid>,
    pub(crate) job_id: Option<Uuid>,
    pub(crate) delivery_mode: Option<&'a str>,
    pub(crate) evidence_key: Option<&'a str>,
    pub(crate) limit: i64,
}

pub(crate) async fn list_attempt_audit(
    pool: &PgPool,
    project_id: Uuid,
    filter: ListAttemptAuditFilter<'_>,
) -> Result<Vec<PublishAttemptAuditRow>, ApiError> {
    let capped_limit = filter.limit.clamp(1, 200);
    let delivery_mode = filter
        .delivery_mode
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string);
    let evidence_key = filter
        .evidence_key
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string);
    sqlx::query_as::<_, PublishAttemptAuditRow>(
        r#"
        SELECT
          a.id,
          a.job_id,
          j.draft_id,
          a.target_id,
          t.platform_id,
          a.attempt_no,
          a.status,
          a.detail,
          a.error_message,
          a.created_at
        FROM app_publish_attempt AS a
        INNER JOIN app_publish_job AS j ON j.id = a.job_id
        INNER JOIN app_publish_target AS t ON t.id = a.target_id
        WHERE j.project_id = $1
          AND ($2::uuid IS NULL OR j.draft_id = $2)
          AND ($3::uuid IS NULL OR j.id = $3)
          AND ($4::text IS NULL OR a.detail->>'delivery_mode' = $4)
          AND ($5::text IS NULL OR COALESCE(a.detail->'evidence', '{}'::jsonb) ? $5)
        ORDER BY a.created_at DESC
        LIMIT $6
        "#,
    )
    .bind(project_id)
    .bind(filter.draft_id)
    .bind(filter.job_id)
    .bind(delivery_mode)
    .bind(evidence_key)
    .bind(capped_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn list_low_performance_alerts(
    pool: &PgPool,
    project_id: Uuid,
    views_lt: i64,
    completion_rate_lt: f64,
    limit: i64,
) -> Result<Vec<PublishPerformanceAlertRow>, ApiError> {
    let capped_limit = limit.clamp(1, 200);
    let capped_views = views_lt.max(0);
    let capped_cr = completion_rate_lt.clamp(0.0, 1.0);
    sqlx::query_as::<_, PublishPerformanceAlertRow>(
        r#"
        SELECT
          s.target_id,
          s.draft_id,
          s.platform_id,
          COALESCE(s.views, 0)::BIGINT AS views,
          COALESCE(s.likes, 0)::BIGINT AS likes,
          COALESCE(s.comments, 0)::BIGINT AS comments,
          COALESCE(s.shares, 0)::BIGINT AS shares,
          COALESCE(s.completion_rate, 0)::DOUBLE PRECISION AS completion_rate,
          s.synced_at
        FROM (
          SELECT DISTINCT ON (target_id)
            target_id, draft_id, platform_id, views, likes, comments, shares, completion_rate, synced_at
          FROM app_publish_performance_snapshot
          WHERE project_id = $1
          ORDER BY target_id, synced_at DESC
        ) AS s
        WHERE (
          COALESCE(s.views, 0) < $2
          OR COALESCE(s.completion_rate, 0)::DOUBLE PRECISION < $3
        )
        ORDER BY s.synced_at DESC
        LIMIT $4
        "#,
    )
    .bind(project_id)
    .bind(capped_views)
    .bind(capped_cr)
    .bind(capped_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn fetch_job_owned(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
) -> Result<Option<PublishJobRow>, ApiError> {
    sqlx::query_as::<_, PublishJobRow>(
        r#"
        SELECT id, project_id, draft_id, owner_user_id, status, semi_auto_ack_at,
               payload, error_message, error_details, claimed_by, created_at, updated_at
        FROM app_publish_job
        WHERE id = $1 AND project_id = $2
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn cancel_job_if_non_terminal(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
) -> Result<bool, ApiError> {
    let res = sqlx::query(
        r#"
        UPDATE app_publish_job SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1 AND project_id = $2
          AND status NOT IN ('succeeded', 'failed', 'cancelled', 'partial_failed')
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() > 0)
}

pub(crate) async fn retry_job_if_allowed(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
) -> Result<bool, ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let draft_id = sqlx::query_scalar::<_, Uuid>(
        r#"
        SELECT draft_id
        FROM app_publish_job
        WHERE id = $1 AND project_id = $2
          AND status IN ('failed', 'cancelled', 'partial_failed')
        FOR UPDATE
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(draft_id) = draft_id else {
        tx.rollback()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Ok(false);
    };

    let targets = sqlx::query_as::<_, PublishTargetRow>(
        r#"
        SELECT id, draft_id, platform_id, automation_mode, serial_order, extra, created_at, updated_at
        FROM app_publish_target
        WHERE draft_id = $1
        ORDER BY serial_order ASC, created_at ASC
        "#,
    )
    .bind(draft_id)
    .fetch_all(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for target in &targets {
        let next_attempt_no: i32 = sqlx::query_scalar(
            r#"
            SELECT COALESCE(MAX(a.attempt_no), 0)::INT + 1
            FROM app_publish_attempt AS a
            WHERE a.job_id = $1 AND a.target_id = $2
            "#,
        )
        .bind(job_id)
        .bind(target.id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        sqlx::query(
            r#"
            INSERT INTO app_publish_attempt (job_id, target_id, attempt_no, status, detail)
            VALUES ($1, $2, $3, 'retrying', $4)
            "#,
        )
        .bind(job_id)
        .bind(target.id)
        .bind(next_attempt_no)
        .bind(Json(json!({
            "event": "manual_retry_requested",
            "platform_id": target.platform_id,
            "recorded_at": chrono::Utc::now().to_rfc3339(),
        })))
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'queued',
          error_message = NULL,
          error_details = NULL,
          claimed_by = NULL,
          semi_auto_ack_at = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(true)
}

pub(crate) async fn confirm_semi_auto_job(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
) -> Result<bool, ApiError> {
    let res = sqlx::query(
        r#"
        UPDATE app_publish_job SET
          semi_auto_ack_at = NOW(),
          status = 'uploading',
          updated_at = NOW()
        WHERE id = $1 AND project_id = $2
          AND status = 'awaiting_confirmation'
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() > 0)
}

pub(crate) async fn claim_next_publish_job(
    pool: &PgPool,
    worker_id: &str,
) -> Result<Option<PublishJobRow>, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let row = sqlx::query_as::<_, PublishJobRow>(
        r#"
        WITH cte AS (
          SELECT j.id
          FROM app_publish_job AS j
          INNER JOIN app_publish_draft AS d ON d.id = j.draft_id
          WHERE (
            j.status IN ('queued', 'retrying')
            OR (j.status = 'uploading' AND j.semi_auto_ack_at IS NOT NULL)
          )
          AND (d.scheduled_at IS NULL OR d.scheduled_at <= NOW())
          ORDER BY j.created_at ASC
          FOR UPDATE OF j SKIP LOCKED
          LIMIT 1
        )
        UPDATE app_publish_job AS j
        SET
          status = CASE
            WHEN j.status IN ('queued', 'retrying') THEN 'validating'
            ELSE j.status
          END,
          claimed_by = $1,
          updated_at = NOW()
        FROM cte
        WHERE j.id = cte.id
        RETURNING j.id, j.project_id, j.draft_id, j.owner_user_id, j.status, j.semi_auto_ack_at,
                  j.payload, j.error_message, j.error_details, j.claimed_by, j.created_at, j.updated_at
        "#,
    )
    .bind(worker_id)
    .fetch_optional(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(row)
}

pub(crate) async fn fail_publish_job_claim(
    pool: &PgPool,
    job_id: Uuid,
    message: &str,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'failed',
          error_message = $2,
          error_details = NULL,
          claimed_by = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .bind(message)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn await_publish_job_confirmation(
    pool: &PgPool,
    job_id: Uuid,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'awaiting_confirmation',
          claimed_by = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn clear_attempts_for_job(pool: &PgPool, job_id: Uuid) -> Result<(), ApiError> {
    sqlx::query(r#"DELETE FROM app_publish_attempt WHERE job_id = $1"#)
        .bind(job_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) struct PublishAttemptUpsert {
    pub(crate) target_id: Uuid,
    pub(crate) attempt_no: i32,
    pub(crate) status: String,
    pub(crate) detail: Value,
    pub(crate) error_message: Option<String>,
}

pub(crate) async fn insert_publish_attempts(
    pool: &PgPool,
    job_id: Uuid,
    attempts: &[PublishAttemptUpsert],
) -> Result<(), ApiError> {
    for attempt in attempts {
        sqlx::query(
            r#"
            INSERT INTO app_publish_attempt (
              job_id, target_id, attempt_no, status, detail, error_message
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            "#,
        )
        .bind(job_id)
        .bind(attempt.target_id)
        .bind(attempt.attempt_no)
        .bind(attempt.status.as_str())
        .bind(Json(attempt.detail.clone()))
        .bind(attempt.error_message.as_deref())
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }
    Ok(())
}

pub(crate) async fn finalize_job_with_attempts(
    pool: &PgPool,
    job_id: Uuid,
    draft_id: Uuid,
    attempts: &[PublishAttemptUpsert],
) -> Result<(), ApiError> {
    let succeeded = attempts.iter().filter(|a| a.status == "succeeded").count();
    let failed = attempts.iter().filter(|a| a.status != "succeeded").count();
    let (final_status, final_error_message): (&str, Option<String>) = if failed == 0 {
        ("succeeded", None)
    } else if succeeded == 0 {
        ("failed", Some("all publish targets failed".to_string()))
    } else {
        (
            "partial_failed",
            Some(format!("{failed} publish targets failed")),
        )
    };

    clear_attempts_for_job(pool, job_id).await?;
    insert_publish_attempts(pool, job_id, attempts).await?;
    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = $2,
          error_message = $3,
          error_details = NULL,
          claimed_by = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .bind(final_status)
    .bind(final_error_message.as_deref())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for attempt in attempts {
        sqlx::query(
            r#"
            UPDATE app_publish_target
            SET
              extra = COALESCE(extra, '{}'::jsonb) || $2,
              updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(attempt.target_id)
        .bind(Json(json!({
            "last_publish_result": {
                "job_id": job_id,
                "attempt_no": attempt.attempt_no,
                "status": attempt.status,
                "error_message": attempt.error_message,
                "detail": attempt.detail,
                "updated_at": chrono::Utc::now().to_rfc3339(),
            }
        })))
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let maybe_external_video_id = attempt
            .detail
            .get("receipt")
            .and_then(|r| r.get("external_video_id"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        let platform_id = attempt
            .detail
            .get("platform_id")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let delivery_mode = attempt
            .detail
            .get("delivery_mode")
            .and_then(|v| v.as_str())
            .filter(|s| !s.trim().is_empty())
            .unwrap_or("unknown")
            .to_string();
        if attempt.status == "succeeded" && !platform_id.is_empty() {
            sqlx::query(
                r#"
                INSERT INTO app_publish_metric_sync_cursor (
                  project_id, target_id, platform_id, status, retry_count, metadata, last_synced_at, updated_at
                )
                SELECT d.project_id, t.id, t.platform_id, 'idle', 0, $2, NULL, NOW()
                FROM app_publish_target AS t
                INNER JOIN app_publish_draft AS d ON d.id = t.draft_id
                WHERE t.id = $1
                ON CONFLICT (project_id, target_id)
                DO UPDATE SET
                  platform_id = EXCLUDED.platform_id,
                  status = 'idle',
                  retry_count = 0,
                  next_retry_at = NULL,
                  last_error = NULL,
                  metadata = COALESCE(app_publish_metric_sync_cursor.metadata, '{}'::jsonb) || EXCLUDED.metadata,
                  updated_at = NOW()
                "#,
            )
            .bind(attempt.target_id)
            .bind(Json(json!({
                "last_publish_job_id": job_id,
                "external_video_id": maybe_external_video_id,
                "delivery_mode": delivery_mode,
                "last_publish_updated_at": chrono::Utc::now().to_rfc3339(),
            })))
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
    }

    sqlx::query(
        r#"
        UPDATE app_publish_draft
        SET
          draft_status = CASE
            WHEN $2 = 'succeeded' THEN 'archived'
            ELSE draft_status
          END,
          metadata = COALESCE(metadata, '{}'::jsonb) || $3,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(draft_id)
    .bind(final_status)
    .bind(Json(json!({
        "last_publish_result": {
            "job_id": job_id,
            "status": final_status,
            "error_message": final_error_message,
            "target_count": attempts.len(),
            "succeeded_count": succeeded,
            "failed_count": failed,
            "updated_at": chrono::Utc::now().to_rfc3339(),
        }
    })))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}
