//! Polls `queued` jobs and runs a minimal in-process worker (MVP). Scales with `FOR UPDATE SKIP LOCKED`.
//! Running jobs can be cancelled via REST; finish updates use `WHERE status = 'running'` so they never
//! overwrite `cancelled`.

use std::time::Duration;

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::{envelope_generation_job_updated, JobRow};
use crate::state::AppState;
use crate::usage;

fn worker_id_label() -> String {
    std::env::var("WORKER_ID")
        .ok()
        .map(|s| s.trim().chars().take(128).collect::<String>())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "default".to_string())
}

pub async fn run(state: AppState) {
    let Some(pool) = state.pool.clone() else {
        tracing::info!("job worker: DATABASE_URL unset; worker not started");
        return;
    };

    let wid = worker_id_label();
    tracing::info!(worker_id = %wid, "job worker: started (poll interval 500ms)");
    let mut interval = tokio::time::interval(Duration::from_millis(500));
    loop {
        interval.tick().await;
        if let Err(e) = process_one_job(&state, &pool, &wid).await {
            tracing::warn!(error = %e, "job worker tick failed");
        }
    }
}

enum JobRunError {
    Failed(String),
    Cancelled,
}

async fn process_one_job(
    state: &AppState,
    pool: &PgPool,
    worker_id: &str,
) -> Result<(), sqlx::Error> {
    let Some(row) = claim_next_job(pool, worker_id).await? else {
        return Ok(());
    };

    let text = envelope_generation_job_updated(&row);
    state
        .notify
        .broadcast_to_user(row.owner_user_id, text)
        .await;

    let owner = row.owner_user_id;
    let id = row.id;

    let outcome = execute_kind(pool, id, &row).await;

    match outcome {
        Ok(result) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'succeeded', result = $1, error_message = NULL, updated_at = NOW()
                WHERE id = $2 AND status = 'running'
                RETURNING id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(result)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(final_row) = updated {
                if let Err(e) =
                    usage::record_generation_job_succeeded(pool, owner, id, &final_row.kind).await
                {
                    tracing::warn!(
                        error = %e,
                        job_id = %id,
                        "app_usage_event insert failed (job still succeeded)"
                    );
                }
                let text = envelope_generation_job_updated(&final_row);
                state.notify.broadcast_to_user(owner, text).await;
            }
            // If None: row was cancelled; cancel_job already sent WS.
        }
        Err(JobRunError::Cancelled) => {
            // Status is already `cancelled`; client was notified by cancel endpoint.
        }
        Err(JobRunError::Failed(msg)) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'failed', error_message = $1, updated_at = NOW()
                WHERE id = $2 AND status = 'running'
                RETURNING id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(msg)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(final_row) = updated {
                let text = envelope_generation_job_updated(&final_row);
                state.notify.broadcast_to_user(owner, text).await;
            }
        }
    }

    Ok(())
}

async fn claim_next_job(pool: &PgPool, worker_id: &str) -> Result<Option<JobRow>, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let row = sqlx::query_as::<_, JobRow>(
        r#"
        WITH cte AS (
            SELECT id FROM app_generation_job
            WHERE status = 'queued'
            ORDER BY created_at ASC
            FOR UPDATE SKIP LOCKED
            LIMIT 1
        )
        UPDATE app_generation_job AS j
        SET status = 'running', claimed_by = $1, updated_at = NOW()
        FROM cte
        WHERE j.id = cte.id
        RETURNING j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.idempotency_key, j.claimed_by, j.created_at, j.updated_at
        "#,
    )
    .bind(worker_id)
    .fetch_optional(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(row)
}

async fn execute_kind(
    pool: &PgPool,
    id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    match row.kind.as_str() {
        "flutter.probe" => {
            // ~1s total; poll so running cancel can land cooperatively.
            for _ in 0..20 {
                tokio::time::sleep(Duration::from_millis(50)).await;
                let st: String =
                    sqlx::query_scalar("SELECT status::text FROM app_generation_job WHERE id = $1")
                        .bind(id)
                        .fetch_one(pool)
                        .await
                        .map_err(|e| JobRunError::Failed(e.to_string()))?;
                if st == "cancelled" {
                    return Err(JobRunError::Cancelled);
                }
            }
            Ok(json!({ "ok": true, "probe": true }))
        }
        other => Err(JobRunError::Failed(format!(
            "unsupported job kind for worker: {other}"
        ))),
    }
}
