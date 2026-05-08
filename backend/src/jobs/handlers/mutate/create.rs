use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{CreateJobBody, JobRow};
use crate::jobs::payload_project::{
    normalize_project_scope_in_job_payload, resolved_workspace_id_from_job_payload,
};
use crate::jobs::{
    hydrate_job_row, merge_client_request_id_from_http_headers, merge_default_track_metadata,
};
use crate::metering::quota;
use crate::metering::usage;
use crate::state::AppState;

use super::super::common::{idempotency_key_header, is_unique_violation, require_pool};

#[utoipa::path(
    post,
    path = "/api/v1/jobs",
    operation_id = "createJobV1",
    tag = "jobs",
    request_body(content = serde_json::Value, content_type = "application/json"),
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
pub(crate) async fn create_job(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateJobBody>,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let kind = body.kind.trim();
    if kind.is_empty() {
        return Err(ApiError::BadRequest("kind must not be empty".into()));
    }

    let idem = idempotency_key_header(&headers);
    if let Some(ref key) = idem {
        if let Some(mut row) = sqlx::query_as::<_, JobRow>(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE owner_user_id = $1 AND idempotency_key = $2
            "#,
        )
        .bind(uid)
        .bind(key)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        {
            hydrate_job_row(&mut row);
            return Ok(Json(row));
        }
    }

    quota::check_daily_job_quota(pool, uid).await?;

    let mut payload = body.payload;
    merge_client_request_id_from_http_headers(&headers, &mut payload);
    merge_default_track_metadata(kind, &mut payload);
    let resolved_workspace_id =
        normalize_project_scope_in_job_payload(pool, uid, &mut payload).await?;

    let insert = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key)
        VALUES ($1, $2, $3, 'queued', $4)
        RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(uid)
    .bind(kind)
    .bind(payload)
    .bind(idem.clone())
    .fetch_one(pool)
    .await;

    let mut row = match insert {
        Ok(r) => r,
        Err(e) if is_unique_violation(&e) => {
            let Some(key) = idem.as_ref() else {
                return Err(ApiError::DatabaseError(e.to_string()));
            };
            let mut r = sqlx::query_as::<_, JobRow>(
                r#"
                SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
                FROM app_generation_job
                WHERE owner_user_id = $1 AND idempotency_key = $2
                "#,
            )
            .bind(uid)
            .bind(key)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .ok_or_else(|| {
                ApiError::DatabaseError("idempotency conflict but row not found".into())
            })?;
            hydrate_job_row(&mut r);
            r
        }
        Err(e) => return Err(ApiError::DatabaseError(e.to_string())),
    };

    hydrate_job_row(&mut row);

    if let Some(workspace_id) =
        resolved_workspace_id.or_else(|| resolved_workspace_id_from_job_payload(&row.payload))
    {
        tracing::info!(
            event = "generation_job_enqueued",
            user_id = %uid,
            job_id = %row.id,
            kind = %row.kind,
            workspace_id = %workspace_id,
            client_request_id = row
                .payload
                .get("client_request_id")
                .or_else(|| row.payload.get("request_id"))
                .and_then(|v| v.as_str())
                .unwrap_or(""),
            "generation job enqueued"
        );
    }

    if let Err(e) = usage::record_generation_job_created(pool, uid, row.id, &row.kind).await {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(Json(row))
}
