//! Polls `queued` jobs and runs a minimal in-process worker (MVP). Scales with `FOR UPDATE SKIP LOCKED`.

use std::time::Duration;

use serde_json::json;
use sqlx::PgPool;

use crate::jobs::{envelope_generation_job_updated, JobRow};
use crate::state::AppState;

pub async fn run(state: AppState) {
    let Some(pool) = state.pool.clone() else {
        tracing::info!("job worker: DATABASE_URL unset; worker not started");
        return;
    };

    tracing::info!("job worker: started (poll interval 500ms)");
    let mut interval = tokio::time::interval(Duration::from_millis(500));
    loop {
        interval.tick().await;
        if let Err(e) = process_one_job(&state, &pool).await {
            tracing::warn!(error = %e, "job worker tick failed");
        }
    }
}

async fn process_one_job(state: &AppState, pool: &PgPool) -> Result<(), sqlx::Error> {
    let Some(row) = claim_next_job(pool).await? else {
        return Ok(());
    };

    let text = envelope_generation_job_updated(&row);
    state
        .notify
        .broadcast_to_user(row.owner_user_id, text)
        .await;

    let owner = row.owner_user_id;
    let id = row.id;

    let outcome = execute_kind(&row).await;

    let final_row = match outcome {
        Ok(result) => {
            sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'succeeded', result = $1, error_message = NULL, updated_at = NOW()
                WHERE id = $2
                RETURNING id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, created_at, updated_at
                "#,
            )
            .bind(result)
            .bind(id)
            .fetch_one(pool)
            .await?
        }
        Err(msg) => {
            sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'failed', error_message = $1, updated_at = NOW()
                WHERE id = $2
                RETURNING id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, created_at, updated_at
                "#,
            )
            .bind(msg)
            .bind(id)
            .fetch_one(pool)
            .await?
        }
    };

    let text = envelope_generation_job_updated(&final_row);
    state.notify.broadcast_to_user(owner, text).await;

    Ok(())
}

async fn claim_next_job(pool: &PgPool) -> Result<Option<JobRow>, sqlx::Error> {
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
        SET status = 'running', updated_at = NOW()
        FROM cte
        WHERE j.id = cte.id
        RETURNING j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.idempotency_key, j.created_at, j.updated_at
        "#,
    )
    .fetch_optional(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(row)
}

async fn execute_kind(row: &JobRow) -> Result<serde_json::Value, String> {
    match row.kind.as_str() {
        "flutter.probe" => {
            tokio::time::sleep(Duration::from_millis(150)).await;
            Ok(json!({ "ok": true, "probe": true }))
        }
        other => Err(format!("unsupported job kind for worker: {other}")),
    }
}
