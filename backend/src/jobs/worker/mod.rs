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

use std::time::Duration;

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::harness::observe;
use crate::llm::{
    chat_completion_assistant_text, images_generation_url, resolve_openai_image_model,
    resolve_openai_image_size, LlmConfig,
};
use crate::metering::usage;
use crate::state::AppState;
use crate::vendor::catalog::lookup_vendor_catalog;
use crate::vendor::credential::decrypt;
use crate::vendor::video::{
    VideoGenerationRequest, VideoGenerationStatus, VideoProvider, VideoProviderClient,
};

use super::{
    envelope_generation_job_updated, JobRow, JOB_KIND_ASSET_GENERATE_BATCH,
    JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH, JOB_KIND_ASSET_POLISH_PROMPT,
    JOB_KIND_FLUTTER_PROBE, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST, JOB_KIND_VIDEO_EXPORT,
    JOB_KIND_VIDEO_GENERATE,
};

mod asset_image;
mod asset_polish;
mod common;
mod vendor;
mod video;

pub(crate) use common::JobRunError;

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

async fn process_one_job(
    state: &AppState,
    pool: &PgPool,
    worker_id: &str,
) -> Result<(), sqlx::Error> {
    let Some(row) = claim_next_job(pool, worker_id).await? else {
        return Ok(());
    };

    observe::generation_job(row.owner_user_id, row.id, "claimed");

    let text = envelope_generation_job_updated(&row);
    state
        .notify
        .broadcast_to_user(row.owner_user_id, text)
        .await;

    let owner = row.owner_user_id;
    let id = row.id;

    let outcome = execute_kind(state, pool, id, &row).await;

    match outcome {
        Ok(result) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'succeeded', result = $1, error_message = NULL, updated_at = NOW()
                WHERE id = $2 AND status = 'running'
                RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(result)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(final_row) = updated {
                observe::generation_job(owner, id, "succeeded");
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
            observe::generation_job(owner, id, "cancelled");
            // Status is already `cancelled`; client was notified by cancel endpoint.
        }
        Err(JobRunError::Failed(msg)) => {
            let updated = sqlx::query_as::<_, JobRow>(
                r#"
                UPDATE app_generation_job
                SET status = 'failed', error_message = $1, updated_at = NOW()
                WHERE id = $2 AND status = 'running'
                RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                "#,
            )
            .bind(msg)
            .bind(id)
            .fetch_optional(pool)
            .await?;

            if let Some(final_row) = updated {
                observe::generation_job(owner, id, "failed");
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
        RETURNING j.numeric_task_id, j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.idempotency_key, j.claimed_by, j.created_at, j.updated_at
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
) -> Result<serde_json::Value, JobRunError> {
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
            Ok(json!({ "ok": true, "probe": true }))
        }
        k if k == JOB_KIND_ASSET_GENERATE_IMAGE => {
            asset_image::run_asset_generate_image(state, pool, id, row).await
        }
        k if k == JOB_KIND_ASSET_POLISH_PROMPT => {
            asset_polish::run_asset_polish_prompt(state, row).await
        }
        k if k == JOB_KIND_ASSET_GENERATE_BATCH => {
            asset_image::run_asset_generate_batch(state, pool, id, row).await
        }
        k if k == JOB_KIND_ASSET_POLISH_BATCH => {
            asset_polish::run_asset_polish_batch(state, pool, id, row).await
        }
        k if k == JOB_KIND_SETTINGS_VENDOR_MODEL_TEST => {
            vendor::run_vendor_model_test(state, pool, row).await
        }
        k if k == JOB_KIND_VIDEO_GENERATE => video::run_video_generate(state, pool, id, row).await,
        k if k == JOB_KIND_VIDEO_EXPORT => video::run_video_export(state, pool, id, row).await,
        other => Err(JobRunError::Failed(format!(
            "unsupported job kind for worker: {other}"
        ))),
    }
}
