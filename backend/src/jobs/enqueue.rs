use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::metering::quota;
use crate::metering::usage;

use super::dto::JobRow;
use super::{hydrate_job_row, merge_default_track_metadata};

/// Enqueue **`queued`** job after quota check (no HTTP idempotency). Records **`generation_job.created`** usage.
pub async fn enqueue_generation_job(
    pool: &PgPool,
    owner_user_id: Uuid,
    kind: &str,
    payload: serde_json::Value,
) -> Result<JobRow, ApiError> {
    quota::check_daily_job_quota(pool, owner_user_id).await?;
    let mut payload = payload;
    merge_default_track_metadata(kind, &mut payload);
    let mut row = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key)
        VALUES ($1, $2, $3, 'queued', NULL)
        RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(owner_user_id)
    .bind(kind)
    .bind(payload)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    hydrate_job_row(&mut row);

    if let Err(e) =
        usage::record_generation_job_created(pool, owner_user_id, row.id, &row.kind).await
    {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(row)
}

/// WebSocket envelope (`docs/websocket-events.md`): full job row as `payload`.
pub fn envelope_generation_job_updated(row: &JobRow) -> String {
    let v = json!({
        "type": "generation.job.updated",
        "schema_version": 1,
        "payload": row,
    });
    serde_json::to_string(&v).expect("JobRow serializes to JSON")
}
