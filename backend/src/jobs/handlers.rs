//! 任务 REST 路由（`GET /api/v1/jobs/*`）。
//!
//! 任务列表、详情、取消和状态查询处理器。

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

use super::dto::{
    CreateJobBody, JobKindSummaryRow, JobRow, JobStatusSummaryRow, ListJobsPageQuery,
    ListJobsPageResponse, ListJobsQuery,
};
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
        WHERE owner_user_id = $1 AND kind <> ''
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

fn normalize_task_page_project_filter(project_id: Option<i32>) -> Option<String> {
    project_id
        .filter(|id| *id > 0)
        .map(|id| id.to_string())
        .filter(|s| !s.is_empty())
}

fn compute_task_page_offset(page: i32, limit: i32) -> i64 {
    i64::from(page - 1) * i64::from(limit)
}

async fn fetch_job_by_legacy_task_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    legacy_task_id: i64,
) -> Result<JobRow, ApiError> {
    sqlx::query_as::<_, JobRow>(
        r#"
        SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1 AND legacy_task_id = $2
        "#,
    )
    .bind(uid)
    .bind(legacy_task_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

async fn list_jobs_page(
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
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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
          AND ($4::text IS NULL OR payload->>'project_legacy_id' = $4)
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
        SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND ($2::text IS NULL OR kind = $2)
          AND ($3::text IS NULL OR status = $3)
          AND ($4::text IS NULL OR payload->>'project_legacy_id' = $4)
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

async fn get_job_task_detail_compat(
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
        return Ok(Json(row));
    }

    if let Ok(legacy) = s.parse::<i64>() {
        if legacy <= 0 {
            return Err(ApiError::BadRequest(
                "task_id must be a UUID or a positive integer".into(),
            ));
        }
        let pool = state
            .pool
            .as_ref()
            .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
        let row = fetch_job_by_legacy_task_id(pool, uid, legacy).await?;
        return Ok(Json(row));
    }

    Err(ApiError::BadRequest(
        "task_id must be a UUID or a positive integer".into(),
    ))
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
        .route("/api/v1/jobs/page", get(list_jobs_page))
        .route(
            "/api/v1/jobs/task-detail/{task_id}",
            get(get_job_task_detail_compat),
        )
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
