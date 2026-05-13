use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{JobKindSummaryRow, JobStatusSummaryRow, JobSummaryQuery};
use crate::state::AppState;

use super::common::{
    ensure_workspace_member_project_numeric_access, normalize_task_page_project_filter,
    payload_matches_project_numeric_clause, require_pool, workspace_visibility_clause,
};

#[utoipa::path(
    get,
    path = "/api/v1/jobs/kinds",
    operation_id = "listJobKindsV1",
    tag = "jobs",
    description = "List distinct job kinds with workspace visibility filtering.

## Visibility Rules

Job kinds are listed based on jobs visible to the authenticated user:

1. **Owner visibility**: Jobs where the user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member visibility**: Jobs associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains project scope fields:
- `project_uuid`: Preferred project UUID (`app_project.id`)
- `project_numeric_id`: Legacy numeric project ID fallback

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and are only visible to the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member visibility. Only the job owner can see job kinds for archived projects.

### Workspace Membership Validation

When filtering by `project_id`, the endpoint validates that the user is a member of the project's workspace. This filter remains the legacy numeric project selector for task-center compatibility. Non-members receive a 403 Forbidden error.",
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
pub(super) async fn list_job_kinds(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<JobSummaryQuery>,
) -> Result<Json<Vec<String>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let project_key = normalize_task_page_project_filter(q.project_id);

    // Build workspace visibility filter:
    // Jobs are visible if:
    // 1. User is the owner (owner_user_id = uid), OR
    // 2. Job has project info (project_uuid or project_numeric_id in payload) AND
    //    user is a member of the project's workspace
    let workspace_visibility_clause = workspace_visibility_clause();

    let kinds: Vec<String> = if let Some(project_key) = project_key.as_deref() {
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;
        let query = format!(
            r#"
            SELECT DISTINCT kind
              FROM app_generation_job
              WHERE {}
              AND {}
              AND kind <> ''
            ORDER BY kind ASC
            "#,
            workspace_visibility_clause,
            payload_matches_project_numeric_clause("$2")
        );
        sqlx::query_scalar(&query)
            .bind(uid)
            .bind(project_key)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        let query = format!(
            r#"
            SELECT DISTINCT kind
            FROM app_generation_job
            WHERE {}
              AND kind <> ''
            ORDER BY kind ASC
            "#,
            workspace_visibility_clause
        );
        sqlx::query_scalar(&query)
            .bind(uid)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };
    Ok(Json(kinds))
}

#[utoipa::path(
    get,
    path = "/api/v1/jobs/kinds/summary",
    operation_id = "listJobKindSummariesV1",
    tag = "jobs",
    description = "Get job count summaries by kind with workspace visibility filtering.

## Visibility Rules

Job counts are aggregated based on jobs visible to the authenticated user:

1. **Owner visibility**: Jobs where the user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member visibility**: Jobs associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains project scope fields:
- `project_uuid`: Preferred project UUID (`app_project.id`)
- `project_numeric_id`: Legacy numeric project ID fallback

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and are only visible to the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member visibility. Only the job owner can see job counts for archived projects.

### Workspace Membership Validation

When filtering by `project_id`, the endpoint validates that the user is a member of the project's workspace. This filter remains the legacy numeric project selector for task-center compatibility. Non-members receive a 403 Forbidden error.",
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
pub(super) async fn list_job_kind_summaries(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<JobSummaryQuery>,
) -> Result<Json<Vec<JobKindSummaryRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let project_key = normalize_task_page_project_filter(q.project_id);

    // Build workspace visibility filter:
    // Jobs are visible if:
    // 1. User is the owner (owner_user_id = uid), OR
    // 2. Job has project info (project_uuid or project_numeric_id in payload) AND
    //    user is a member of the project's workspace
    let workspace_visibility_clause = workspace_visibility_clause();

    let rows = if let Some(project_key) = project_key.as_deref() {
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;
        let query = format!(
            r#"
            SELECT kind, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE {}
              AND {}
            GROUP BY kind
            ORDER BY kind ASC
            "#,
            workspace_visibility_clause,
            payload_matches_project_numeric_clause("$2")
        );
        sqlx::query_as::<_, JobKindSummaryRow>(&query)
            .bind(uid)
            .bind(project_key)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        let query = format!(
            r#"
            SELECT kind, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE {}
            GROUP BY kind
            ORDER BY kind ASC
            "#,
            workspace_visibility_clause
        );
        sqlx::query_as::<_, JobKindSummaryRow>(&query)
            .bind(uid)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };
    Ok(Json(rows))
}

#[utoipa::path(
    get,
    path = "/api/v1/jobs/status/summary",
    operation_id = "listJobStatusSummariesV1",
    tag = "jobs",
    description = "Get job count summaries by status with workspace visibility filtering.

## Visibility Rules

Job counts are aggregated based on jobs visible to the authenticated user:

1. **Owner visibility**: Jobs where the user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member visibility**: Jobs associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains project scope fields:
- `project_uuid`: Preferred project UUID (`app_project.id`)
- `project_numeric_id`: Legacy numeric project ID fallback

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and are only visible to the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member visibility. Only the job owner can see job counts for archived projects.

### Workspace Membership Validation

When filtering by `project_id`, the endpoint validates that the user is a member of the project's workspace. This filter remains the legacy numeric project selector for task-center compatibility. Non-members receive a 403 Forbidden error.",
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
pub(super) async fn list_job_status_summaries(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<JobSummaryQuery>,
) -> Result<Json<Vec<JobStatusSummaryRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let project_key = normalize_task_page_project_filter(q.project_id);

    // Build workspace visibility filter:
    // Jobs are visible if:
    // 1. User is the owner (owner_user_id = uid), OR
    // 2. Job has project info (project_uuid or project_numeric_id in payload) AND
    //    user is a member of the project's workspace
    let workspace_visibility_clause = workspace_visibility_clause();

    let rows = if let Some(project_key) = project_key.as_deref() {
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;
        let query = format!(
            r#"
            SELECT status, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE {}
              AND {}
            GROUP BY status
            ORDER BY status ASC
            "#,
            workspace_visibility_clause,
            payload_matches_project_numeric_clause("$2")
        );
        sqlx::query_as::<_, JobStatusSummaryRow>(&query)
            .bind(uid)
            .bind(project_key)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        let query = format!(
            r#"
            SELECT status, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE {}
            GROUP BY status
            ORDER BY status ASC
            "#,
            workspace_visibility_clause
        );
        sqlx::query_as::<_, JobStatusSummaryRow>(&query)
            .bind(uid)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };
    Ok(Json(rows))
}
