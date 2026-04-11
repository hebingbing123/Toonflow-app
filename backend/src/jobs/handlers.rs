use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::quota;
use crate::metering::usage;
use crate::state::AppState;

use super::dto::{CreateJobBody, JobKindSummaryRow, JobRow, JobStatusSummaryRow, ListJobsQuery};
use super::enqueue::envelope_generation_job_updated;

pub(crate) fn idempotency_key_header(headers: &HeaderMap) -> Option<String> {
    headers
        .get("idempotency-key")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.chars().take(200).collect())
}

fn is_unique_violation(e: &sqlx::Error) -> bool {
    match e {
        sqlx::Error::Database(db) => db.code().map(|c| c == "23505").unwrap_or(false),
        _ => false,
    }
}

async fn list_job_kinds(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<String>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let kinds: Vec<String> = sqlx::query_scalar(
        r#"
        SELECT DISTINCT kind
        FROM app_generation_job
        WHERE owner_user_id = $1
        ORDER BY kind ASC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(kinds))
}

async fn list_job_kind_summaries(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<JobKindSummaryRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let rows = sqlx::query_as::<_, JobKindSummaryRow>(
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

async fn list_job_status_summaries(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<JobStatusSummaryRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let rows = sqlx::query_as::<_, JobStatusSummaryRow>(
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

pub(crate) fn trim_query_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub(crate) fn normalize_job_list_status_filter(
    raw: Option<String>,
) -> Result<Option<String>, ApiError> {
    let Some(s) = trim_query_opt(raw) else {
        return Ok(None);
    };
    let s = s.to_ascii_lowercase();
    if matches!(
        s.as_str(),
        "queued" | "running" | "succeeded" | "failed" | "cancelled"
    ) {
        Ok(Some(s))
    } else {
        Err(ApiError::BadRequest(
            "status must be one of: queued, running, succeeded, failed, cancelled".into(),
        ))
    }
}

pub(crate) fn list_jobs_limit_offset(
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(i64, i64), ApiError> {
    let limit = match limit {
        None => 100,
        Some(x) if (1..=100).contains(&x) => x,
        Some(_) => {
            return Err(ApiError::BadRequest(
                "limit must be between 1 and 100".into(),
            ));
        }
    };
    let offset = offset.unwrap_or(0);
    if offset < 0 {
        return Err(ApiError::BadRequest(
            "offset must be greater than or equal to 0".into(),
        ));
    }
    Ok((limit, offset))
}

async fn list_jobs(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListJobsQuery>,
) -> Result<Json<Vec<JobRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let kind = trim_query_opt(q.kind);
    let status = normalize_job_list_status_filter(q.status)?;
    let (limit, offset) = list_jobs_limit_offset(q.limit, q.offset)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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

async fn create_job(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateJobBody>,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let kind = body.kind.trim();
    if kind.is_empty() {
        return Err(ApiError::BadRequest("kind must not be empty".into()));
    }

    let idem = idempotency_key_header(&headers);
    if let Some(ref key) = idem {
        if let Some(row) = sqlx::query_as::<_, JobRow>(
            r#"
            SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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
            return Ok(Json(row));
        }
    }

    quota::check_daily_job_quota(pool, uid).await?;

    let insert = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key)
        VALUES ($1, $2, $3, 'queued', $4)
        RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(uid)
    .bind(kind)
    .bind(body.payload)
    .bind(idem.clone())
    .fetch_one(pool)
    .await;

    let row = match insert {
        Ok(r) => r,
        Err(e) if is_unique_violation(&e) => {
            let Some(key) = idem.as_ref() else {
                return Err(ApiError::DatabaseError(e.to_string()));
            };
            sqlx::query_as::<_, JobRow>(
                r#"
                SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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
            })?
        }
        Err(e) => return Err(ApiError::DatabaseError(e.to_string())),
    };

    if let Err(e) = usage::record_generation_job_created(pool, uid, row.id, &row.kind).await {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(Json(row))
}

async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let row = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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
    Ok(Json(row))
}

async fn cancel_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let updated = sqlx::query_as::<_, JobRow>(
        r#"
        UPDATE app_generation_job
        SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2 AND status IN ('queued', 'running')
        RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(row) = updated {
        let text = envelope_generation_job_updated(&row);
        state.notify.broadcast_to_user(uid, text).await;
        return Ok(Json(row));
    }

    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM app_generation_job WHERE id = $1 AND owner_user_id = $2)",
    )
    .bind(id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !exists {
        return Err(ApiError::NotFound);
    }

    Err(ApiError::Conflict(
        "job cannot be cancelled in its current status (not queued or running)".into(),
    ))
}

async fn retry_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let updated = sqlx::query_as::<_, JobRow>(
        r#"
        UPDATE app_generation_job
        SET status = 'queued', error_message = NULL, result = NULL, claimed_by = NULL, updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2 AND status = 'failed'
        RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(row) = updated {
        let text = envelope_generation_job_updated(&row);
        state.notify.broadcast_to_user(uid, text).await;
        return Ok(Json(row));
    }

    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM app_generation_job WHERE id = $1 AND owner_user_id = $2)",
    )
    .bind(id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !exists {
        return Err(ApiError::NotFound);
    }

    Err(ApiError::Conflict(
        "only failed jobs can be retried (re-queue)".into(),
    ))
}

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/jobs/kinds/summary", get(list_job_kind_summaries))
        .route("/api/v1/jobs/kinds", get(list_job_kinds))
        .route(
            "/api/v1/jobs/status/summary",
            get(list_job_status_summaries),
        )
        .route("/api/v1/jobs", get(list_jobs).post(create_job))
        .route("/api/v1/jobs/{id}", get(get_job))
        .route("/api/v1/jobs/{id}/cancel", post(cancel_job))
        .route("/api/v1/jobs/{id}/retry", post(retry_job))
}
