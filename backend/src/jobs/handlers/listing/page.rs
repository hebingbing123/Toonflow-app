use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{JobRow, ListJobsPageQuery, ListJobsPageResponse};
use crate::jobs::hydrate_job_rows;
use crate::state::AppState;

use super::super::common::{
    compute_task_page_offset, ensure_workspace_member_project_numeric_access,
    normalize_task_page_project_filter, payload_matches_project_numeric_clause, require_pool,
    trim_query_opt, workspace_visibility_clause,
};

#[utoipa::path(
    get,
    path = "/api/v1/jobs/page",
    operation_id = "listJobsPageV1",
    tag = "jobs",
    description = "List jobs with pagination and workspace visibility filtering.

## Visibility Rules

Jobs are visible to the authenticated user if:

1. **Owner visibility**: The user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member visibility**: The job is associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains project scope fields:
- `project_uuid`: Preferred project UUID (`app_project.id`)
- `project_numeric_id`: Legacy numeric project ID fallback

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and are only visible to the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member visibility. Only the job owner can see jobs for archived projects.

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
pub(crate) async fn list_jobs_page(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListJobsPageQuery>,
) -> Result<Json<ListJobsPageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let page = q.page.unwrap_or(1);
    let limit = q.limit.unwrap_or(20);
    if page < 1 {
        return Err(crate::error::bad_request_i18n(
            "page must be >= 1",
            "page 必须大于或等于 1",
        ));
    }
    if !(1..=100).contains(&limit) {
        return Err(crate::error::bad_request_i18n(
            "limit must be between 1 and 100",
            "limit 必须在 1 到 100 之间",
        ));
    }
    let pool = require_pool(&state)?;

    let kind = trim_query_opt(q.task_class);
    let status = trim_query_opt(q.state);
    let project_key = normalize_task_page_project_filter(q.project_id);

    let offset = compute_task_page_offset(page, limit);

    // Build workspace visibility filter:
    // Jobs are visible if:
    // 1. User is the owner (owner_user_id = uid), OR
    // 2. Job has project info (project_uuid or project_numeric_id in payload) AND
    //    user is a member of the project's workspace
    let workspace_visibility_clause = workspace_visibility_clause();

    let (total, mut rows) = if let Some(project_key) = project_key.as_deref() {
        // When filtering by project, ensure user has access to that project
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;

        let count_query = format!(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE {}
              AND {}
              AND ($3::text IS NULL OR kind = $3)
              AND ($4::text IS NULL OR status = $4)
            "#,
            workspace_visibility_clause,
            payload_matches_project_numeric_clause("$2")
        );

        let total: i64 = sqlx::query_scalar(&count_query)
            .bind(uid)
            .bind(project_key)
            .bind(kind.as_deref())
            .bind(status.as_deref())
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let select_query = format!(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE {}
              AND {}
              AND ($3::text IS NULL OR kind = $3)
              AND ($4::text IS NULL OR status = $4)
            ORDER BY created_at DESC
            OFFSET $5
            LIMIT $6
            "#,
            workspace_visibility_clause,
            payload_matches_project_numeric_clause("$2")
        );

        let rows = sqlx::query_as::<_, JobRow>(&select_query)
            .bind(uid)
            .bind(project_key)
            .bind(kind.as_deref())
            .bind(status.as_deref())
            .bind(offset)
            .bind(i64::from(limit))
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        (total, rows)
    } else {
        // No project filter: show all jobs visible to the user
        let count_query = format!(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE {}
              AND ($2::text IS NULL OR kind = $2)
              AND ($3::text IS NULL OR status = $3)
            "#,
            workspace_visibility_clause
        );

        let total: i64 = sqlx::query_scalar(&count_query)
            .bind(uid)
            .bind(kind.as_deref())
            .bind(status.as_deref())
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let select_query = format!(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE {}
              AND ($2::text IS NULL OR kind = $2)
              AND ($3::text IS NULL OR status = $3)
            ORDER BY created_at DESC
            OFFSET $4
            LIMIT $5
            "#,
            workspace_visibility_clause
        );

        let rows = sqlx::query_as::<_, JobRow>(&select_query)
            .bind(uid)
            .bind(kind.as_deref())
            .bind(status.as_deref())
            .bind(offset)
            .bind(i64::from(limit))
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        (total, rows)
    };

    hydrate_job_rows(&mut rows);

    Ok(Json(ListJobsPageResponse { data: rows, total }))
}
