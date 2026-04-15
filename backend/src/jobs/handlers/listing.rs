use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{JobRow, ListJobsPageQuery, ListJobsPageResponse, ListJobsQuery};
use crate::state::AppState;

use super::common::{
    compute_task_page_offset, fetch_job_by_id, fetch_job_by_numeric_task_id,
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
pub(super) async fn list_jobs(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListJobsQuery>,
) -> Result<Json<Vec<JobRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let kind = trim_query_opt(q.kind);
    let status = normalize_job_list_status_filter(q.status)?;
    let (limit, offset) = list_jobs_limit_offset(q.limit, q.offset)?;
    let pool = require_pool(&state)?;
    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

#[utoipa::path(
    get,
    path = "/api/v1/jobs/page",
    operation_id = "listJobsPageV1",
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
pub(super) async fn list_jobs_page(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListJobsPageQuery>,
) -> Result<Json<ListJobsPageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let page = q.page.unwrap_or(1);
    let limit = q.limit.unwrap_or(20);
    if page < 1 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if !(1..=100).contains(&limit) {
        return Err(ApiError::BadRequest(
            "limit must be between 1 and 100".into(),
        ));
    }
    let pool = require_pool(&state)?;

    let kind = trim_query_opt(q.task_class);
    let status = trim_query_opt(q.state);
    let project_key = normalize_task_page_project_filter(q.project_id);

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND ($2::text IS NULL OR kind = $2)
          AND ($3::text IS NULL OR status = $3)
          AND ($4::text IS NULL OR payload->>'project_numeric_id' = $4)
        "#,
    )
    .bind(uid)
    .bind(kind.as_deref())
    .bind(status.as_deref())
    .bind(project_key.as_deref())
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let offset = compute_task_page_offset(page, limit);
    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND ($2::text IS NULL OR kind = $2)
          AND ($3::text IS NULL OR status = $3)
          AND ($4::text IS NULL OR payload->>'project_numeric_id' = $4)
        ORDER BY created_at DESC
        OFFSET $5
        LIMIT $6
        "#,
    )
    .bind(uid)
    .bind(kind.as_deref())
    .bind(status.as_deref())
    .bind(project_key.as_deref())
    .bind(offset)
    .bind(i64::from(limit))
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ListJobsPageResponse { data: rows, total }))
}

#[utoipa::path(
    get,
    path = "/api/v1/jobs/task-detail/{task_id}",
    operation_id = "getJobTaskDetailCompatV1",
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
pub(super) async fn get_job_task_detail_compat(
    State(state): State<AppState>,
    Path(task_id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    let s = task_id.trim();
    if s.is_empty() {
        return Err(ApiError::BadRequest(
            "task_id path segment must not be empty".into(),
        ));
    }

    if let Ok(id) = Uuid::parse_str(s) {
        let pool = require_pool(&state)?;
        let row = fetch_job_by_id(pool, uid, id).await?;
        return Ok(Json(row));
    }

    if let Ok(parsed_task) = s.parse::<i64>() {
        if parsed_task <= 0 {
            return Err(ApiError::BadRequest(
                "task_id must be a UUID or a positive integer".into(),
            ));
        }
        let pool = require_pool(&state)?;
        let row = fetch_job_by_numeric_task_id(pool, uid, parsed_task).await?;
        return Ok(Json(row));
    }

    Err(ApiError::BadRequest(
        "task_id must be a UUID or a positive integer".into(),
    ))
}

#[utoipa::path(
    get,
    path = "/api/v1/jobs/{id}",
    operation_id = "getJobV1",
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
pub(super) async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let row = fetch_job_by_id(pool, uid, id).await?;
    Ok(Json(row))
}
