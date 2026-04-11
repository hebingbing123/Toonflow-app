//! 共享的 Worker 错误类型和取消轮询辅助函数。

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
