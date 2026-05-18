//! 写入 `app_usage_event`（任务创建/成功等审计）。

use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

/// Optional billing fields stored on succeeded job usage events.
#[derive(Debug, Clone, Default)]
pub struct JobUsageBillingMeta {
    pub model_id: Option<String>,
    pub credits_charged: Option<u64>,
}

/// Called when a generation job reaches `succeeded` (best-effort; failures are logged only).
pub async fn record_generation_job_succeeded(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
    billing: JobUsageBillingMeta,
) -> Result<(), sqlx::Error> {
    record_job_event(
        pool,
        user_id,
        job_id,
        job_kind,
        "generation_job.succeeded",
        Some(billing),
    )
    .await
}

/// Called when a new generation job is created (best-effort; used for quota audit trail).
pub async fn record_generation_job_created(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
) -> Result<(), sqlx::Error> {
    record_job_event(
        pool,
        user_id,
        job_id,
        job_kind,
        "generation_job.created",
        None,
    )
    .await
}

async fn record_job_event(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
    event_type: &str,
    billing: Option<JobUsageBillingMeta>,
) -> Result<(), sqlx::Error> {
    let mut payload = json!({ "kind": job_kind });
    if let Some(meta) = billing {
        merge_billing_into_payload(&mut payload, &meta);
    }
    sqlx::query(
        r#"
        INSERT INTO app_usage_event (user_id, event_type, source_job_id, payload)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(user_id)
    .bind(event_type)
    .bind(job_id)
    .bind(payload)
    .execute(pool)
    .await?;
    Ok(())
}

fn merge_billing_into_payload(payload: &mut Value, meta: &JobUsageBillingMeta) {
    if let Some(ref model_id) = meta.model_id {
        payload["model_id"] = json!(model_id);
    }
    if let Some(credits) = meta.credits_charged {
        payload["credits_charged"] = json!(credits);
    }
}
