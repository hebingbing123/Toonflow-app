use axum::http::HeaderMap;
use uuid::Uuid;

use crate::error::ApiError;
use crate::jobs::dto::JobRow;

pub(crate) fn require_pool(state: &crate::state::AppState) -> Result<&sqlx::PgPool, ApiError> {
    state.require_pool()
}

pub(crate) fn idempotency_key_header(headers: &HeaderMap) -> Option<String> {
    headers
        .get("idempotency-key")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.chars().take(200).collect())
}

pub(crate) fn is_unique_violation(e: &sqlx::Error) -> bool {
    e.as_database_error()
        .and_then(|db| db.code())
        .is_some_and(|code| code == "23505")
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

pub(crate) fn normalize_task_page_project_filter(project_id: Option<i32>) -> Option<String> {
    project_id
        .filter(|id| *id > 0)
        .map(|id| id.to_string())
        .filter(|s| !s.is_empty())
}

pub(crate) fn compute_task_page_offset(page: i32, limit: i32) -> i64 {
    i64::from(page - 1) * i64::from(limit)
}

pub(crate) async fn fetch_job_by_numeric_task_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    numeric_task_id: i64,
) -> Result<JobRow, ApiError> {
    sqlx::query_as::<_, JobRow>(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1 AND numeric_task_id = $2
        "#,
    )
    .bind(uid)
    .bind(numeric_task_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

pub(crate) async fn fetch_job_by_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    id: Uuid,
) -> Result<JobRow, ApiError> {
    sqlx::query_as::<_, JobRow>(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}
