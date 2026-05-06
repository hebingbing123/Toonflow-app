//! Metric operations for publish store.

use serde_json::Value;
use sqlx::types::Json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::publish::types::PublishMetricSyncCursorRow;
pub(crate) async fn claim_next_metric_sync_cursor(
    pool: &PgPool,
) -> Result<Option<PublishMetricSyncCursorRow>, ApiError> {
    sqlx::query_as::<_, PublishMetricSyncCursorRow>(
        r#"
        WITH cte AS (
          SELECT id
          FROM app_publish_metric_sync_cursor
          WHERE status IN ('idle', 'retrying')
            AND (next_retry_at IS NULL OR next_retry_at <= NOW())
          ORDER BY COALESCE(last_synced_at, '1970-01-01'::timestamptz) ASC, updated_at ASC
          LIMIT 1
          FOR UPDATE SKIP LOCKED
        )
        UPDATE app_publish_metric_sync_cursor AS c
        SET status = 'running', updated_at = NOW()
        FROM cte
        WHERE c.id = cte.id
        RETURNING
          c.id, c.project_id, c.target_id, c.platform_id, c.cursor_token, c.status, c.retry_count,
          c.next_retry_at, c.last_error, c.metadata, c.last_synced_at, c.updated_at
        "#,
    )
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn complete_metric_sync_cursor(
    pool: &PgPool,
    cursor_id: Uuid,
    metadata_patch: Value,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_publish_metric_sync_cursor
        SET
          status = 'idle',
          retry_count = 0,
          next_retry_at = NULL,
          last_error = NULL,
          metadata = COALESCE(metadata, '{}'::jsonb) || $2,
          last_synced_at = NOW(),
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(cursor_id)
    .bind(Json(metadata_patch))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn fail_metric_sync_cursor(
    pool: &PgPool,
    cursor_id: Uuid,
    retry_count: i32,
    message: &str,
) -> Result<(), ApiError> {
    let retry_delay_min = (retry_count.max(1) * 5).min(60);
    sqlx::query(
        r#"
        UPDATE app_publish_metric_sync_cursor
        SET
          status = 'retrying',
          retry_count = $2,
          next_retry_at = NOW() + make_interval(mins => $3),
          last_error = $4,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(cursor_id)
    .bind(retry_count)
    .bind(retry_delay_min)
    .bind(message)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) struct PublishPerformanceSnapshotUpsert {
    pub(crate) project_id: Uuid,
    pub(crate) target_id: Uuid,
    pub(crate) platform_id: String,
    pub(crate) external_video_id: Option<String>,
    pub(crate) metric_window: String,
    pub(crate) views: i64,
    pub(crate) likes: i64,
    pub(crate) comments: i64,
    pub(crate) shares: i64,
    pub(crate) completion_rate: f64,
    pub(crate) raw_payload: Value,
}

pub(crate) async fn insert_publish_performance_snapshot(
    pool: &PgPool,
    upsert: &PublishPerformanceSnapshotUpsert,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_publish_performance_snapshot (
          project_id, draft_id, target_id, platform_id, external_video_id, metric_window,
          views, likes, comments, shares, completion_rate, raw_payload, synced_at
        )
        SELECT
          $1, t.draft_id, $2, $3, $4, $5,
          $6, $7, $8, $9, $10, $11, NOW()
        FROM app_publish_target AS t
        WHERE t.id = $2
        "#,
    )
    .bind(upsert.project_id)
    .bind(upsert.target_id)
    .bind(upsert.platform_id.as_str())
    .bind(upsert.external_video_id.as_deref())
    .bind(upsert.metric_window.as_str())
    .bind(upsert.views)
    .bind(upsert.likes)
    .bind(upsert.comments)
    .bind(upsert.shares)
    .bind(upsert.completion_rate)
    .bind(Json(upsert.raw_payload.clone()))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
