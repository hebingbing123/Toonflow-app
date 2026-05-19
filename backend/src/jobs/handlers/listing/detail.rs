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
    description = "Get job details by task ID (compatibility endpoint) with workspace visibility validation.

This endpoint accepts either a UUID or a numeric task ID for backward compatibility.

## Visibility Rules

A job is accessible to the authenticated user if:

1. **Owner access**: The user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member access**: The job is associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains project scope fields:
- `project_uuid`: Preferred project UUID (`app_project.id`)
- `project_numeric_id`: Legacy numeric project ID fallback

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and are only accessible to the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member access. Only the job owner can access jobs for archived projects.

### Access Denied

If the user does not have access to the job, the endpoint returns 404 Not Found (not 403 Forbidden) to maintain security by not revealing the existence of jobs the user cannot access.",
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
        return Err(crate::error::bad_request_i18n(
            "task_id path segment must not be empty",
            "task_id 路径段不能为空",
        ));
    }

    if let Ok(id) = Uuid::parse_str(s) {
        let pool = require_pool(&state)?;
        let row = fetch_job_by_id(pool, uid, id).await?;
        return Ok(Json(row));
    }

    if let Ok(parsed_task) = s.parse::<i64>() {
        if parsed_task <= 0 {
            return Err(crate::error::bad_request_i18n(
                "task_id must be a UUID or a positive integer",
                "task_id 必须是 UUID 或正整数",
            ));
        }
        let pool = require_pool(&state)?;
        let row = fetch_job_by_numeric_task_id(pool, uid, parsed_task).await?;
        return Ok(Json(row));
    }

    Err(crate::error::bad_request_i18n(
        "task_id must be a UUID or a positive integer",
        "task_id 必须是 UUID 或正整数",
    ))
}

#[utoipa::path(
    get,
    path = "/api/v1/jobs/{id}",
    operation_id = "getJobV1",
    tag = "jobs",
    description = "Get job details by ID with workspace visibility validation.

## Visibility Rules

A job is accessible to the authenticated user if:

1. **Owner access**: The user is the job owner (`owner_user_id` matches the authenticated user)
2. **Workspace member access**: The job is associated with a project in a workspace where the user is a member

### Project Association

Jobs are associated with a project when the job payload contains project scope fields:
- `project_uuid`: Preferred project UUID (`app_project.id`)
- `project_numeric_id`: Legacy numeric project ID fallback

### Personal Jobs

Jobs without project information (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and are only accessible to the job owner.

### Archived Projects

Jobs associated with archived projects are excluded from workspace member access. Only the job owner can access jobs for archived projects.

### Access Denied

If the user does not have access to the job, the endpoint returns 404 Not Found (not 403 Forbidden) to maintain security by not revealing the existence of jobs the user cannot access.",
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
    if row.kind != crate::jobs::JOB_KIND_VIDEO_EXPORT
        && row.kind != crate::jobs::JOB_KIND_VOICEOVER_GENERATE
        && row.kind != crate::jobs::JOB_KIND_SHORT_VIDEO_PRE_ASSEMBLY
        && row.kind != crate::jobs::JOB_KIND_SHORT_VIDEO_TIMELINE_PREVIEW
    {
        return Err(ApiError::NotFound);
    }

    let file = sqlx::query_as::<_, JobFileSource>(
        r#"
        SELECT result
        FROM app_generation_job
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let result = file.result.0;
    if result.get("storage").and_then(|value| value.as_str()) == Some("local") {
        let root = if row.kind == crate::jobs::JOB_KIND_VOICEOVER_GENERATE {
            state.local_voiceover_audio_dir.as_ref()
        } else {
            state.local_video_export_dir.as_ref()
        };
        let Some(root) = root else {
            return Err(ApiError::DatabaseError(
                if row.kind == crate::jobs::JOB_KIND_VOICEOVER_GENERATE {
                    "OPENFLOW_LOCAL_VOICEOVER_AUDIO_DIR is not set; cannot serve locally stored voiceover audio"
                        .into()
                } else {
                    "OPENFLOW_LOCAL_VIDEO_EXPORT_DIR is not set; cannot serve locally stored export artifacts"
                        .into()
                },
            ));
        };
        let file_name = result
            .get("file_name")
            .and_then(|value| value.as_str())
            .filter(|value| !value.trim().is_empty())
            .ok_or(ApiError::NotFound)?;
        let path = root.join(row.owner_user_id.to_string()).join(file_name);
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
        let _: axum::http::Uri = export_url.parse().map_err(|_| {
            crate::error::bad_request_i18n(
                "job export_url is not a valid URL",
                "job export_url 不是有效的 URL",
            )
        })?;
        return Ok(Redirect::temporary(export_url).into_response());
    }

    Err(ApiError::NotFound)
}
