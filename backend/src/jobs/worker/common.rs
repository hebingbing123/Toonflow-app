//! 共享的 Worker 错误类型和取消轮询辅助函数。

use sqlx::PgPool;
use uuid::Uuid;

pub(crate) enum JobRunError {
    Failed(String),
    /// Machine-oriented payload persisted as `app_generation_job.error_details` when status=`failed`.
    FailedStructured {
        message: String,
        error_details: serde_json::Value,
    },
    Cancelled,
}

/// Worker success payload: JSON `result` plus optional `error_details` persisted even when status=`succeeded`
/// (e.g. provider succeeded but DB writeback did not land — MP-W4 / J4).
pub(crate) type JobCompletion = (serde_json::Value, Option<serde_json::Value>);

#[inline]
pub(crate) fn job_ok(result: serde_json::Value) -> JobCompletion {
    (result, None)
}

#[inline]
pub(crate) fn job_ok_with_details(
    result: serde_json::Value,
    error_details: serde_json::Value,
) -> JobCompletion {
    (result, Some(error_details))
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
