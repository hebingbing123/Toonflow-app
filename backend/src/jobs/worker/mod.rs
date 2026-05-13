//! 任务 Worker：轮询并执行队列中的任务。
//!
//! 使用 `FOR UPDATE SKIP LOCKED` 实现可扩展的分布式任务处理。
//! 运行中的任务可通过 REST 取消；完成更新使用 `WHERE status = 'running'` 确保不会覆盖已取消状态。
//!
//! 子模块：
//! - `common` — 错误处理和取消探测
//! - `asset_polish` — 资产提示词优化
//! - `asset_image` — 资产图片生成
//! - `vendor` — 提供商测试
//! - `video` — 视频生成
//! - `voiceover` — 旁白配音生成

use std::time::Duration;

use serde_json::{json, to_value as json_to_value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::payload_project::resolved_workspace_id_from_job_payload;
use crate::jobs::queue::{PgQueue, Queue};
use crate::metering::usage;
use crate::settings::account::build_account_export_artifact;
use crate::settings::notifications::workspace_audit_export::build_workspace_shared_audit_export_artifact;
use crate::settings::outbound_webhooks::fire_job_terminal_outbound_webhooks;
use crate::state::AppState;

use super::{
    envelope_generation_job_updated, hydrate_job_row, record_job_notification, JobRow,
    JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH,
    JOB_KIND_ASSET_POLISH_PROMPT, JOB_KIND_FLUTTER_PROBE, JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH,
    JOB_KIND_SETTINGS_ACCOUNT_EXPORT, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST,
    JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT, JOB_KIND_VIDEO_EXPORT,
    JOB_KIND_VIDEO_GENERATE, JOB_KIND_VOICEOVER_GENERATE,
};

mod asset_image;
mod asset_polish;
mod common;
mod novel_crawl;
mod vendor;
mod video;
mod voiceover;

#[cfg(test)]
mod workspace_validation_tests;

pub(crate) use common::{job_ok, JobCompletion, JobRunError};

/// Optional idempotency / trace bridge: HTTP may copy **`X-Request-Id`** into enqueue **`payload`**.
fn client_request_id_from_payload(payload: &serde_json::Value) -> Option<&str> {
    payload
        .get("client_request_id")
        .or_else(|| payload.get("request_id"))
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
}

fn log_generation_job_phase(
    user_id: Uuid,
    job_id: Uuid,
    kind: &str,
    phase: &'static str,
    worker_id: &str,
    workspace_id: Option<Uuid>,
    client_request_id: Option<&str>,
) {
    let rid = client_request_id.unwrap_or("");
    match workspace_id {
        Some(workspace_id) => tracing::info!(
            event = "generation_job_phase",
            user_id = %user_id,
            job_id = %job_id,
            kind = %kind,
            phase,
            worker_id = %worker_id,
            workspace_id = %workspace_id,
            client_request_id = rid,
            "app_generation_job lifecycle (worker)"
        ),
        None => tracing::info!(
            event = "generation_job_phase",
            user_id = %user_id,
            job_id = %job_id,
            kind = %kind,
            phase,
            worker_id = %worker_id,
            client_request_id = rid,
            "app_generation_job lifecycle (worker)"
        ),
    }
}

fn worker_id_label() -> String {
    std::env::var("WORKER_ID")
        .ok()
        .map(|s| s.trim().chars().take(128).collect::<String>())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "default".to_string())
}

/// Seconds between structured `job_queue_metrics` logs (`0` = disabled). Default **60**.
fn queue_metrics_interval_secs() -> u64 {
    std::env::var("JOB_QUEUE_METRICS_INTERVAL_SECS")
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(60)
}

async fn fire_outbound_for_terminal_job(
    pool: &PgPool,
    http: &reqwest::Client,
    row: &JobRow,
    event_type: &'static str,
) {
    let job_ws = resolved_workspace_id_from_job_payload(&row.payload);
    match json_to_value(row) {
        Ok(job_json) => {
            if let Err(e) = fire_job_terminal_outbound_webhooks(
                pool,
                http,
                row.owner_user_id,
                job_ws,
                job_json,
                event_type,
            )
            .await
            {
                tracing::warn!(
                    error = %e,
                    job_id = %row.id,
                    event_type,
                    "fire_job_terminal_outbound_webhooks failed"
                );
            }
        }
        Err(e) => tracing::warn!(
            error = %e,
            job_id = %row.id,
            "serialize job row for outbound webhooks failed"
        ),
    }
}

async fn log_queue_metrics(pool: &PgPool, worker_id: &str) {
    let queue = PgQueue::new(pool.clone());
    match queue.stats().await {
        Ok(stats) => {
            tracing::info!(
                worker_id = %worker_id,
                pending = stats.pending,
                pending_claimable = stats.pending_claimable,
                running = stats.running,
                dead = stats.dead,
                failed_last_24h = stats.failed_last_24h,
                oldest_claimable_queued_age_secs = ?stats.oldest_claimable_queued_age_secs,
                pending_by_kind = %stats.pending_by_kind_json,
                event = "job_queue_metrics",
                "PG job queue depth"
            );
        }
        Err(e) => tracing::warn!(
            error = %e,
            worker_id = %worker_id,
            "job queue metrics query failed"
        ),
    }
}

pub async fn run(state: AppState) {
    let Some(pool) = state.pool.clone() else {
        tracing::info!("job worker: DATABASE_URL unset; worker not started");
        return;
    };

    let wid = worker_id_label();
    let metrics_secs = queue_metrics_interval_secs();
    if metrics_secs == 0 {
        tracing::info!(worker_id = %wid, "job worker: queue metrics logging disabled (JOB_QUEUE_METRICS_INTERVAL_SECS=0)");
    } else {
        tracing::info!(
            worker_id = %wid,
            interval_secs = metrics_secs,
            "job worker: queue metrics interval (JOB_QUEUE_METRICS_INTERVAL_SECS)"
        );
    }

    tracing::info!(worker_id = %wid, "job worker: started (poll interval 500ms)");
    let mut interval = tokio::time::interval(Duration::from_millis(500));
    let metrics_interval = if metrics_secs > 0 {
        Some(Duration::from_secs(metrics_secs))
    } else {
        None
    };
    let mut last_metrics = std::time::Instant::now();
    loop {
        interval.tick().await;
        if let Some(period) = metrics_interval {
            if last_metrics.elapsed() >= period {
                last_metrics = std::time::Instant::now();
                log_queue_metrics(&pool, &wid).await;
            }
        }
        if let Err(e) = process_one_job(&state, &pool, &wid).await {
            tracing::warn!(error = %e, "job worker tick failed");
        }
    }
}

async fn process_one_job(
    state: &AppState,
    pool: &PgPool,
    worker_id: &str,
) -> Result<(), sqlx::Error> {
    let Some(mut row) = claim_next_job(pool, worker_id).await? else {
        return Ok(());
    };

    hydrate_job_row(&mut row);

    let job_kind = row.kind.clone();
    let client_rid = client_request_id_from_payload(&row.payload);
    log_generation_job_phase(
        row.owner_user_id,
        row.id,
        job_kind.as_str(),
        "claimed",
        worker_id,
        resolved_workspace_id_from_job_payload(&row.payload),
        client_rid,
    );

    // All user-facing job worker pushes share the same raw WS envelope:
    // `generation.job.updated` with the full job row in `payload`.
    let text = envelope_generation_job_updated(&row);
    state
        .notify
        .broadcast_to_user(row.owner_user_id, text)
        .await;

    let owner = row.owner_user_id;
    let id = row.id;

    let outcome = execute_kind(state, pool, id, &row).await;

    match outcome {
        Ok((result, error_details)) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'succeeded', result = $1, error_message = NULL, error_details = $2, updated_at = NOW()
                WHERE id = $3 AND status = 'running'
                RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(result)
            .bind(error_details)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(mut final_row) = updated {
                log_generation_job_phase(
                    owner,
                    id,
                    final_row.kind.as_str(),
                    "succeeded",
                    worker_id,
                    resolved_workspace_id_from_job_payload(&final_row.payload),
                    client_request_id_from_payload(&final_row.payload),
                );
                if let Err(e) =
                    usage::record_generation_job_succeeded(pool, owner, id, &final_row.kind).await
                {
                    tracing::warn!(
                        error = %e,
                        job_id = %id,
                        "app_usage_event insert failed (job still succeeded)"
                    );
                }
                hydrate_job_row(&mut final_row);
                if let Err(error) = record_job_notification(state, &final_row).await {
                    tracing::warn!(error = ?error, job_id = %final_row.id, "failed to record succeeded job notification");
                }
                let text = envelope_generation_job_updated(&final_row);
                state.notify.broadcast_to_user(owner, text).await;
                fire_outbound_for_terminal_job(
                    pool,
                    &state.http_client,
                    &final_row,
                    "job.completed",
                )
                .await;
            }
            // If None: row was cancelled; cancel_job already sent WS.
        }
        Err(JobRunError::Cancelled) => {
            log_generation_job_phase(
                owner,
                id,
                job_kind.as_str(),
                "cancelled",
                worker_id,
                resolved_workspace_id_from_job_payload(&row.payload),
                client_rid,
            );
            // Status is already `cancelled`; client was notified by cancel endpoint.
        }
        Err(JobRunError::Failed(msg)) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'failed', error_message = $1, error_details = NULL, updated_at = NOW()
                WHERE id = $2 AND status = 'running'
                RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(msg)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(mut final_row) = updated {
                log_generation_job_phase(
                    owner,
                    id,
                    final_row.kind.as_str(),
                    "failed",
                    worker_id,
                    resolved_workspace_id_from_job_payload(&final_row.payload),
                    client_request_id_from_payload(&final_row.payload),
                );
                hydrate_job_row(&mut final_row);
                if let Err(error) = record_job_notification(state, &final_row).await {
                    tracing::warn!(error = ?error, job_id = %final_row.id, "failed to record failed job notification");
                }
                let text = envelope_generation_job_updated(&final_row);
                state.notify.broadcast_to_user(owner, text).await;
                fire_outbound_for_terminal_job(pool, &state.http_client, &final_row, "job.failed")
                    .await;
            }
        }
        Err(JobRunError::FailedStructured {
            message,
            error_details,
        }) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'failed', error_message = $1, error_details = $2, updated_at = NOW()
                WHERE id = $3 AND status = 'running'
                RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(message)
            .bind(error_details)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(mut final_row) = updated {
                log_generation_job_phase(
                    owner,
                    id,
                    final_row.kind.as_str(),
                    "failed",
                    worker_id,
                    resolved_workspace_id_from_job_payload(&final_row.payload),
                    client_request_id_from_payload(&final_row.payload),
                );
                hydrate_job_row(&mut final_row);
                if let Err(error) = record_job_notification(state, &final_row).await {
                    tracing::warn!(error = ?error, job_id = %final_row.id, "failed to record structured failed job notification");
                }
                let text = envelope_generation_job_updated(&final_row);
                state.notify.broadcast_to_user(owner, text).await;
                fire_outbound_for_terminal_job(pool, &state.http_client, &final_row, "job.failed")
                    .await;
            }
        }
    }

    Ok(())
}

/// PostgreSQL contract tests: one worker iteration (**`queued`** → claim → execute → terminal).
pub async fn contract_worker_process_one_tick(
    state: &AppState,
    pool: &PgPool,
) -> Result<(), sqlx::Error> {
    process_one_job(state, pool, "pg-contract").await
}

async fn claim_next_job(pool: &PgPool, worker_id: &str) -> Result<Option<JobRow>, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let row = sqlx::query_as::<_, JobRow>(
        r#"
        WITH cte AS (
            SELECT id FROM app_generation_job
            WHERE status = 'queued'
              AND (
                payload->>'run_at_ms' IS NULL
                OR (
                  (payload->>'run_at_ms') ~ '^[0-9]+$'
                  AND (payload->>'run_at_ms')::bigint <= (EXTRACT(EPOCH FROM NOW()) * 1000)::bigint
                )
              )
            ORDER BY created_at ASC
            FOR UPDATE SKIP LOCKED
            LIMIT 1
        )
        UPDATE app_generation_job AS j
        SET status = 'running', claimed_by = $1, updated_at = NOW()
        FROM cte
        WHERE j.id = cte.id
        RETURNING j.numeric_task_id, j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.error_details, j.idempotency_key, j.claimed_by, j.created_at, j.updated_at
        "#,
    )
    .bind(worker_id)
    .fetch_optional(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(row)
}

async fn execute_kind(
    state: &AppState,
    pool: &PgPool,
    id: Uuid,
    row: &JobRow,
) -> Result<JobCompletion, JobRunError> {
    match row.kind.as_str() {
        k if k == JOB_KIND_FLUTTER_PROBE => {
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
            Ok(job_ok(json!({ "ok": true, "probe": true })))
        }
        k if k == JOB_KIND_ASSET_GENERATE_IMAGE => {
            asset_image::run_asset_generate_image(state, pool, id, row)
                .await
                .map(job_ok)
        }
        k if k == JOB_KIND_ASSET_POLISH_PROMPT => {
            asset_polish::run_asset_polish_prompt(state, pool, id, row)
                .await
                .map(job_ok)
        }
        k if k == JOB_KIND_ASSET_GENERATE_BATCH => {
            asset_image::run_asset_generate_batch(state, pool, id, row)
                .await
                .map(job_ok)
        }
        k if k == JOB_KIND_ASSET_POLISH_BATCH => {
            asset_polish::run_asset_polish_batch(state, pool, id, row)
                .await
                .map(job_ok)
        }
        k if k == JOB_KIND_SETTINGS_VENDOR_MODEL_TEST => {
            vendor::run_vendor_model_test(state, pool, row)
                .await
                .map(job_ok)
        }
        k if k == JOB_KIND_SETTINGS_ACCOUNT_EXPORT => {
            build_account_export_artifact(pool, row.owner_user_id, id, &row.payload).await
        }
        k if k == JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT => {
            build_workspace_shared_audit_export_artifact(pool, row.owner_user_id, id, &row.payload)
                .await
        }
        k if k == JOB_KIND_VIDEO_GENERATE => video::run_video_generate(state, pool, id, row).await,
        k if k == JOB_KIND_VIDEO_EXPORT => video::run_video_export(state, pool, id, row).await,
        k if k == JOB_KIND_VOICEOVER_GENERATE => {
            voiceover::run_voiceover_generate(state, pool, id, row)
                .await
                .map(job_ok)
        }
        k if k == JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH => {
            novel_crawl::run_novel_crawl_import_batch(state, pool, row).await
        }
        other => Err(JobRunError::Failed(format!(
            "unsupported job kind for worker: {other}"
        ))),
    }
}
