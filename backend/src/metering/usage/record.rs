//! 写入 `app_usage_event`（任务创建/成功等审计）。

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

/// Called when a generation job reaches `succeeded` (best-effort; failures are logged only).
pub async fn record_generation_job_succeeded(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
) -> Result<(), sqlx::Error> {
    record_job_event(pool, user_id, job_id, job_kind, "generation_job.succeeded").await
}

/// Called when a new generation job is created (best-effort; used for quota audit trail).
pub async fn record_generation_job_created(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
) -> Result<(), sqlx::Error> {
    record_job_event(pool, user_id, job_id, job_kind, "generation_job.created").await
}

async fn record_job_event(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
    event_type: &str,
) -> Result<(), sqlx::Error> {
    let payload = json!({ "kind": job_kind });
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
