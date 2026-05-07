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
    require_pool,
};

#[utoipa::path(
    get,
    path = "/api/v1/jobs/kinds",
    operation_id = "listJobKindsV1",
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
pub(super) async fn list_job_kinds(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<JobSummaryQuery>,
) -> Result<Json<Vec<String>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let project_key = normalize_task_page_project_filter(q.project_id);
    let kinds: Vec<String> = if let Some(project_key) = project_key.as_deref() {
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;
        sqlx::query_scalar(
            r#"
            SELECT DISTINCT kind
            FROM app_generation_job
            WHERE payload->>'project_numeric_id' = $1 AND kind <> ''
            ORDER BY kind ASC
            "#,
        )
        .bind(project_key)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_scalar(
            r#"
            SELECT DISTINCT kind
            FROM app_generation_job
            WHERE owner_user_id = $1 AND kind <> ''
            ORDER BY kind ASC
            "#,
        )
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
    let rows = if let Some(project_key) = project_key.as_deref() {
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;
        sqlx::query_as::<_, JobKindSummaryRow>(
            r#"
            SELECT kind, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE payload->>'project_numeric_id' = $1
            GROUP BY kind
            ORDER BY kind ASC
            "#,
        )
        .bind(project_key)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as::<_, JobKindSummaryRow>(
            r#"
            SELECT kind, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE owner_user_id = $1
            GROUP BY kind
            ORDER BY kind ASC
            "#,
        )
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
    let rows = if let Some(project_key) = project_key.as_deref() {
        ensure_workspace_member_project_numeric_access(pool, uid, project_key).await?;
        sqlx::query_as::<_, JobStatusSummaryRow>(
            r#"
            SELECT status, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE payload->>'project_numeric_id' = $1
            GROUP BY status
            ORDER BY status ASC
            "#,
        )
        .bind(project_key)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as::<_, JobStatusSummaryRow>(
            r#"
            SELECT status, COUNT(*)::bigint AS job_count
            FROM app_generation_job
            WHERE owner_user_id = $1
            GROUP BY status
            ORDER BY status ASC
            "#,
        )
        .bind(uid)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };
    Ok(Json(rows))
}
