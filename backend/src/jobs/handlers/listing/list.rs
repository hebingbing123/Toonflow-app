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
    list_jobs_limit_offset, normalize_job_list_status_filter, normalize_task_page_project_filter,
    require_pool, trim_query_opt,
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
    let mut rows = if let Some(project_key) = project_key.as_deref() {
        let has_project_access: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS (
              SELECT 1
              FROM app_project p
              INNER JOIN app_workspace_member wm ON wm.workspace_id = p.workspace_id
              WHERE p.numeric_id::text = $1
                AND wm.user_id = $2
            )
            "#,
        )
        .bind(project_key)
        .bind(uid)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if !has_project_access {
            return Err(ApiError::NotFound);
        }

        sqlx::query_as::<_, JobRow>(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE payload->>'project_numeric_id' = $1
              AND ($2::text IS NULL OR kind = $2)
              AND ($3::text IS NULL OR status = $3)
            ORDER BY created_at DESC
            LIMIT $4 OFFSET $5
            "#,
        )
        .bind(project_key)
        .bind(kind)
        .bind(status)
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as::<_, JobRow>(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE owner_user_id = $1
              AND ($2::text IS NULL OR kind = $2)
              AND ($3::text IS NULL OR status = $3)
            ORDER BY created_at DESC
            LIMIT $4 OFFSET $5
            "#,
        )
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
