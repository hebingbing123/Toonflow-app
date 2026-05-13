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
    description = "Cancel a job with workspace membership validation.

## Permission Requirements

A user can cancel a job if:

1. **Owner permission**: The user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member permission**: The job is associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains:
- `project_uuid`: The UUID of the project
- `project_numeric_id`: The numeric ID of the project

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and can only be cancelled by the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member permissions. Only the job owner can cancel jobs for archived projects.

### Status Requirements

Only jobs in `queued` or `running` status can be cancelled. Attempting to cancel a job in any other status returns 409 Conflict.

### Access Denied

If the user does not have permission to cancel the job, the endpoint returns 404 Not Found (not 403 Forbidden) to maintain security by not revealing the existence of jobs the user cannot access.",
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

    // First validate access using the new permission check
    let current = super::super::common::require_job_access(pool, uid, id).await?;

    // Only allow cancellation if job is in queued or running status
    if !matches!(current.status.as_str(), "queued" | "running") {
        return Err(ApiError::Conflict(
            "job cannot be cancelled in its current status (not queued or running)".into(),
        ));
    }

    // Perform the cancellation
    let updated = sqlx::query_as::<_, JobRow>(
        r#"
        UPDATE app_generation_job
        SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1
          AND status IN ('queued', 'running')
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
        "job cannot be cancelled in its current status (not queued or running)",
    )
    .await
}
