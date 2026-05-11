use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{JobRow, ListJobsQuery};
use crate::jobs::hydrate_job_rows;
use crate::state::AppState;

use super::super::common::{
    ensure_workspace_member_project_numeric_access, list_jobs_limit_offset,
    normalize_job_list_status_filter, normalize_task_page_project_filter, require_pool,
    trim_query_opt,
};

#[utoipa::path(
    get,
    path = "/api/v1/jobs",
    operation_id = "listJobsV1",
    tag = "jobs",
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
pub(crate) async fn list_jobs(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListJobsQuery>,
) -> Result<Json<Vec<JobRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let kind = trim_query_opt(q.kind);
    let status = normalize_job_list_status_filter(q.status)?;
    let project_key = normalize_task_page_project_filter(q.project_id);
    let (limit, offset) = list_jobs_limit_offset(q.limit, q.offset)?;
    let pool = require_pool(&state)?;

    // Build workspace visibility filter:
    // Jobs are visible if:
    // 1. User is the owner (owner_user_id = uid), OR
    // 2. Job has project info (project_uuid or project_numeric_id in payload) AND
    //    user is a member of the project's workspace
    let workspace_visibility_clause = r#"
        (
            app_generation_job.owner_user_id = $1
            OR EXISTS (
                SELECT 1
                FROM app_project p
                INNER JOIN app_workspace_member wm ON wm.workspace_id = p.workspace_id
                WHERE wm.user_id = $1
                  AND (
                    (app_generation_job.payload->>'project_uuid' IS NOT NULL 
                     AND p.id::text = app_generation_job.payload->>'project_uuid')
                    OR
                    (app_generation_job.payload->>'project_numeric_id' IS NOT NULL
                     AND (app_generation_job.payload->>'project_numeric_id') ~ '^[0-9]+$'
                     AND p.numeric_id = (app_generation_job.payload->>'project_numeric_id')::int)
                  )
                  AND p.archived_at IS NULL
            )
        )
    "#;

    let mut rows = if let Some(project_key) = project_key.as_deref() {
        // When filtering by project, ensure user has access to that project
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;

        let select_query = format!(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE {}
              AND payload->>'project_numeric_id' = $2
              AND ($3::text IS NULL OR kind = $3)
              AND ($4::text IS NULL OR status = $4)
            ORDER BY created_at DESC
            LIMIT $5 OFFSET $6
            "#,
            workspace_visibility_clause
        );

        sqlx::query_as::<_, JobRow>(&select_query)
            .bind(uid)
            .bind(project_key)
            .bind(kind)
            .bind(status)
            .bind(limit)
            .bind(offset)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        // No project filter: show all jobs visible to the user
        let select_query = format!(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE {}
              AND ($2::text IS NULL OR kind = $2)
              AND ($3::text IS NULL OR status = $3)
            ORDER BY created_at DESC
            LIMIT $4 OFFSET $5
            "#,
            workspace_visibility_clause
        );

        sqlx::query_as::<_, JobRow>(&select_query)
            .bind(uid)
            .bind(kind)
            .bind(status)
            .bind(limit)
            .bind(offset)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };
    hydrate_job_rows(&mut rows);
    Ok(Json(rows))
}
