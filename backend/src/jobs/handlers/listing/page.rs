use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{JobRow, ListJobsPageQuery, ListJobsPageResponse};
use crate::state::AppState;

use super::super::common::{
    compute_task_page_offset, normalize_task_page_project_filter, require_pool, trim_query_opt,
};

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
pub(crate) async fn list_jobs_page(
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
