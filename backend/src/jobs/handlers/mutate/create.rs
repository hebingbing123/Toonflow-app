use axum::{extract::State, http::HeaderMap, Json};
use serde_json::Value;
use uuid::Uuid;

use crate::assets::resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::dto::{CreateJobBody, JobRow};
use crate::jobs::{
    hydrate_job_row, merge_client_request_id_from_http_headers, merge_default_track_metadata,
};
use crate::metering::quota;
use crate::metering::usage;
use crate::state::AppState;

use super::super::common::{idempotency_key_header, is_unique_violation, require_pool};

fn payload_project_uuid(payload: &Value) -> Option<Uuid> {
    payload
        .get("project_uuid")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s.trim()).ok())
}

fn payload_project_numeric(payload: &Value) -> Option<i32> {
    payload
        .get("project_numeric_id")
        .and_then(|v| v.as_i64())
        .and_then(|n| i32::try_from(n).ok())
}

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
    let payload_project_uuid = payload_project_uuid(&payload);
    let payload_project_numeric = payload_project_numeric(&payload);
    if payload_project_uuid.is_some() || payload_project_numeric.is_some() {
        let (project_uuid, project_numeric_id, _workspace_id) =
            resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
                pool,
                uid,
                payload_project_uuid,
                payload_project_numeric,
            )
            .await?;
        payload["project_uuid"] = Value::String(project_uuid.to_string());
        payload["project_numeric_id"] = Value::Number(project_numeric_id.into());
    }

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

    if let Err(e) = usage::record_generation_job_created(pool, uid, row.id, &row.kind).await {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(Json(row))
}
