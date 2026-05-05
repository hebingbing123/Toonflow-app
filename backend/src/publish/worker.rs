//! Publish job worker (**E7/F7**) — validates drafts, respects semi-auto gate, dispatches per-platform adapters.

use std::time::Duration;

use sqlx::PgPool;

use crate::publish::adapters::{fetch_platform_metrics_mock, run_target_adapter};
use crate::publish::store::{
    await_publish_job_confirmation, claim_next_metric_sync_cursor, claim_next_publish_job,
    complete_metric_sync_cursor, fail_metric_sync_cursor, fail_publish_job_claim,
    finalize_job_with_attempts, insert_publish_performance_snapshot, list_targets,
    PublishAttemptUpsert, PublishPerformanceSnapshotUpsert,
};
use crate::publish::{store, validation};
use crate::state::AppState;

fn worker_id_label() -> String {
    std::env::var("PUBLISH_WORKER_ID")
        .ok()
        .map(|s| s.trim().chars().take(128).collect::<String>())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "publish-default".to_string())
}

fn metric_sync_interval_ms() -> u64 {
    std::env::var("PUBLISH_METRIC_SYNC_INTERVAL_MS")
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .filter(|v| *v >= 500)
        .unwrap_or(5_000)
}

pub async fn run(state: AppState) {
    let Some(pool) = state.pool.clone() else {
        tracing::info!("publish worker: DATABASE_URL unset; not started");
        return;
    };

    let wid = worker_id_label();
    let metric_ms = metric_sync_interval_ms();
    tracing::info!(
        worker_id = %wid,
        metric_sync_interval_ms = metric_ms,
        "publish worker: started (poll interval 750ms)"
    );
    let mut interval = tokio::time::interval(Duration::from_millis(750));
    let mut metric_interval = tokio::time::interval(Duration::from_millis(metric_ms));
    loop {
        tokio::select! {
            _ = interval.tick() => {
                if let Err(e) = process_one_publish_job(&pool, &wid).await {
                    tracing::warn!(error = %e, "publish worker tick failed");
                }
            }
            _ = metric_interval.tick() => {
                if let Err(e) = process_one_metric_sync(&pool).await {
                    tracing::warn!(error = %e, "publish metrics sync tick failed");
                }
            }
        }
    }
}

async fn process_one_publish_job(pool: &PgPool, worker_id: &str) -> Result<(), String> {
    let Some(job) = claim_next_publish_job(pool, worker_id)
        .await
        .map_err(|e| e.to_string())?
    else {
        return Ok(());
    };

    let draft = match store::fetch_draft(pool, job.project_id, job.draft_id).await {
        Ok(d) => d,
        Err(e) => {
            fail_publish_job_claim(pool, job.id, &format!("database error: {e:?}"))
                .await
                .map_err(|x| format!("{x:?}"))?;
            return Ok(());
        }
    };

    let Some(draft) = draft else {
        fail_publish_job_claim(pool, job.id, "publish draft missing")
            .await
            .map_err(|e| format!("{e:?}"))?;
        return Ok(());
    };

    let targets = list_targets(pool, job.draft_id)
        .await
        .map_err(|e| format!("{e:?}"))?;
    let issues = validation::prepare_check_for_draft(&draft, &targets);
    if issues.iter().any(|i| i.severity == "blocking") {
        let msg = issues
            .first()
            .map(|i| i.message.as_str())
            .unwrap_or("publish prepare check failed");
        fail_publish_job_claim(pool, job.id, msg)
            .await
            .map_err(|e| format!("{e:?}"))?;
        return Ok(());
    }

    let semi = store::draft_has_semi_auto_target(pool, job.draft_id)
        .await
        .map_err(|e| format!("{e:?}"))?;
    if semi && job.semi_auto_ack_at.is_none() {
        await_publish_job_confirmation(pool, job.id)
            .await
            .map_err(|e| format!("{e:?}"))?;
        return Ok(());
    }

    let attempts = targets
        .iter()
        .enumerate()
        .map(|(idx, target)| {
            let result = run_target_adapter(&job, &draft, target);
            PublishAttemptUpsert {
                target_id: target.id,
                attempt_no: idx as i32 + 1,
                status: result.status.to_string(),
                detail: result.detail,
                error_message: result.error_message,
            }
        })
        .collect::<Vec<_>>();

    finalize_job_with_attempts(pool, job.id, job.draft_id, &attempts)
        .await
        .map_err(|e| format!("{e:?}"))?;
    Ok(())
}

async fn process_one_metric_sync(pool: &PgPool) -> Result<(), String> {
    let Some(cursor) = claim_next_metric_sync_cursor(pool)
        .await
        .map_err(|e| format!("{e:?}"))?
    else {
        return Ok(());
    };

    let external_video_id = cursor
        .metadata
        .0
        .get("external_video_id")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.to_string());
    let Some(external_video_id) = external_video_id else {
        fail_metric_sync_cursor(
            pool,
            cursor.id,
            cursor.retry_count + 1,
            "missing external_video_id in sync cursor metadata",
        )
        .await
        .map_err(|e| format!("{e:?}"))?;
        return Ok(());
    };

    let metrics = fetch_platform_metrics_mock(&cursor.platform_id, &external_video_id);
    insert_publish_performance_snapshot(
        pool,
        &PublishPerformanceSnapshotUpsert {
            project_id: cursor.project_id,
            target_id: cursor.target_id,
            platform_id: cursor.platform_id.clone(),
            external_video_id: Some(external_video_id.clone()),
            metric_window: metrics.metric_window.to_string(),
            views: metrics.views,
            likes: metrics.likes,
            comments: metrics.comments,
            shares: metrics.shares,
            completion_rate: metrics.completion_rate,
            raw_payload: metrics.raw_payload,
        },
    )
    .await
    .map_err(|e| format!("{e:?}"))?;

    complete_metric_sync_cursor(
        pool,
        cursor.id,
        serde_json::json!({
            "last_snapshot_synced_at": chrono::Utc::now().to_rfc3339(),
        }),
    )
    .await
    .map_err(|e| format!("{e:?}"))?;
    Ok(())
}
