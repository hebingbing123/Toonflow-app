//! Job persistence repository (rebuild plan P0-5 pilot).

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::jobs::dto::JobRow;

pub struct JobRepository;

impl JobRepository {
    pub async fn find_by_idempotency_key(
        pool: &PgPool,
        owner_user_id: Uuid,
        idempotency_key: &str,
    ) -> Result<Option<JobRow>, ApiError> {
        sqlx::query_as::<_, JobRow>(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result,
                   error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE owner_user_id = $1 AND idempotency_key = $2
            "#,
        )
        .bind(owner_user_id)
        .bind(idempotency_key)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
    }
}
