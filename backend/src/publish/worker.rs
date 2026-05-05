//! Publish job worker (**E7/F7**) — validates drafts, respects semi-auto gate, dispatches per-platform adapters.

use std::time::Duration;

use sqlx::PgPool;

use crate::publish::adapters::run_target_adapter;
use crate::publish::store::{
    await_publish_job_confirmation, claim_next_publish_job, fail_publish_job_claim,
    finalize_job_with_attempts, list_targets, PublishAttemptUpsert,
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

pub async fn run(state: AppState) {
    let Some(pool) = state.pool.clone() else {
        tracing::info!("publish worker: DATABASE_URL unset; not started");
        return;
    };

    let wid = worker_id_label();
    tracing::info!(worker_id = %wid, "publish worker: started (poll interval 750ms)");
    let mut interval = tokio::time::interval(Duration::from_millis(750));
    loop {
        interval.tick().await;
        if let Err(e) = process_one_publish_job(&pool, &wid).await {
            tracing::warn!(error = %e, "publish worker tick failed");
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
