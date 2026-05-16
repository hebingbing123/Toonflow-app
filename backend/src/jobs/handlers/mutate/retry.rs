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

use super::super::common::{job_status_allows_retry, require_pool};
use super::outcome::resolve_job_mutation_outcome;

#[utoipa::path(
    post,
    path = "/api/v1/jobs/{id}/retry",
    operation_id = "retryJobV1",
    tag = "jobs",
    description = "Retry a failed job with workspace membership validation.

## Permission Requirements

A user can retry a job if:

1. **Owner permission**: The user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member permission**: The job is associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains project scope fields:
- `project_uuid`: Preferred project UUID (`app_project.id`)
- `project_numeric_id`: Legacy numeric project ID fallback

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and can only be retried by the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member permissions. Only the job owner can retry jobs for archived projects.

### Status Requirements

Only jobs in `failed` status can be retried. Attempting to retry a job in any other status returns 409 Conflict.

### Access Denied

If the user does not have permission to retry the job, the endpoint returns 404 Not Found (not 403 Forbidden) to maintain security by not revealing the existence of jobs the user cannot access.",
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
pub(crate) async fn retry_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;

    // First validate access using the new permission check
    let current = super::super::common::require_job_access(pool, uid, id).await?;

    if !job_status_allows_retry(&current.status) {
        return Err(ApiError::Conflict(
            "only failed jobs can be retried (re-queue)".into(),
        ));
    }

    // Perform the retry
    let updated = sqlx::query_as::<_, JobRow>(
        r#"
        UPDATE app_generation_job
        SET status = 'queued', error_message = NULL, result = NULL, error_details = NULL, claimed_by = NULL, updated_at = NOW()
        WHERE id = $1
          AND status = 'failed'
        RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    resolve_job_mutation_outcome(
        &state,
        pool,
        uid,
        id,
        updated,
        "only failed jobs can be retried (re-queue)",
    )
    .await
}
