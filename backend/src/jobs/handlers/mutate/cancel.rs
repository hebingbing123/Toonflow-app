use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::JobRow;
use crate::state::AppState;

use super::super::common::require_pool;
use super::outcome::resolve_job_mutation_outcome;

#[utoipa::path(
    post,
    path = "/api/v1/jobs/{id}/cancel",
    operation_id = "cancelJobV1",
    tag = "jobs",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 429, description = "Too many requests", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn cancel_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;

    let updated = sqlx::query_as::<_, JobRow>(
        r#"
        UPDATE app_generation_job
        SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2 AND status IN ('queued', 'running')
        RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    resolve_job_mutation_outcome(
        &state,
        pool,
        uid,
        id,
        updated,
        "job cannot be cancelled in its current status (not queued or running)",
    )
    .await
}
