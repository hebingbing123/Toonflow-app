//! Shared worker error type and cancel polling helper.

use sqlx::PgPool;
use uuid::Uuid;

pub(crate) enum JobRunError {
    Failed(String),
    Cancelled,
}

pub(crate) async fn generation_job_is_cancelled(
    pool: &PgPool,
    job_id: Uuid,
) -> Result<bool, JobRunError> {
    let st: String =
        sqlx::query_scalar("SELECT status::text FROM app_generation_job WHERE id = $1")
            .bind(job_id)
            .fetch_one(pool)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
    Ok(st == "cancelled")
}
