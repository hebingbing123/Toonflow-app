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

use super::super::common::{fetch_job_by_id, fetch_job_by_numeric_task_id, require_pool};

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
pub(crate) async fn get_job_task_detail_compat(
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
pub(crate) async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let row = fetch_job_by_id(pool, uid, id).await?;
    Ok(Json(row))
}
