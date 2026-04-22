use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Redirect, Response},
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{JobFileSource, JobRow};
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

#[utoipa::path(
    get,
    path = "/api/v1/jobs/{id}/file",
    operation_id = "getJobFileV1",
    tag = "jobs",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 302, description = "Redirect to remote artifact"),
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
pub(crate) async fn get_job_file(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let row = fetch_job_by_id(pool, uid, id).await?;
    if row.kind != crate::jobs::JOB_KIND_VIDEO_EXPORT {
        return Err(ApiError::NotFound);
    }

    let file = sqlx::query_as::<_, JobFileSource>(
        r#"
        SELECT result
        FROM app_generation_job
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let result = file.result.0;
    if result.get("storage").and_then(|value| value.as_str()) == Some("local") {
        let Some(root) = state.local_video_export_dir.as_ref() else {
            return Err(ApiError::DatabaseError(
                "TOONFLOW_LOCAL_VIDEO_EXPORT_DIR is not set; cannot serve locally stored exported videos"
                    .into(),
            ));
        };
        let file_name = result
            .get("file_name")
            .and_then(|value| value.as_str())
            .filter(|value| !value.trim().is_empty())
            .ok_or(ApiError::NotFound)?;
        let path = root.join(uid.to_string()).join(file_name);
        let bytes = tokio::fs::read(&path)
            .await
            .map_err(|_| ApiError::NotFound)?;
        let content_type = result
            .get("content_type")
            .and_then(|value| value.as_str())
            .filter(|value| !value.trim().is_empty())
            .unwrap_or("application/octet-stream");
        return Ok((
            StatusCode::OK,
            [
                (header::CONTENT_TYPE, content_type),
                (header::CACHE_CONTROL, "private, max-age=300"),
            ],
            Body::from(bytes),
        )
            .into_response());
    }

    let Some(export_url) = result
        .get("export_url")
        .and_then(|value| value.as_str())
        .map(str::trim)
        .filter(|value| !value.is_empty())
    else {
        return Err(ApiError::NotFound);
    };
    if export_url.starts_with("http://") || export_url.starts_with("https://") {
        let _: axum::http::Uri = export_url
            .parse()
            .map_err(|_| ApiError::BadRequest("job export_url is not a valid URL".into()))?;
        return Ok(Redirect::temporary(export_url).into_response());
    }

    Err(ApiError::NotFound)
}
