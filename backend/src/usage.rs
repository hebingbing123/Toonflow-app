//! Usage metering (`app_usage_event`, §12.3): record server-side outcomes and expose per-user counts.

use std::collections::HashMap;

use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::get;
use axum::{Json, Router};
use serde::Serialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

/// Called when a generation job reaches `succeeded` (best-effort; failures are logged only).
pub async fn record_generation_job_succeeded(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
) -> Result<(), sqlx::Error> {
    record_job_event(pool, user_id, job_id, job_kind, "generation_job.succeeded").await
}

/// Called when a new generation job is created (best-effort; used for quota audit trail).
pub async fn record_generation_job_created(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
) -> Result<(), sqlx::Error> {
    record_job_event(pool, user_id, job_id, job_kind, "generation_job.created").await
}

async fn record_job_event(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
    job_kind: &str,
    event_type: &str,
) -> Result<(), sqlx::Error> {
    let payload = json!({ "kind": job_kind });
    sqlx::query(
        r#"
        INSERT INTO app_usage_event (user_id, event_type, source_job_id, payload)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(user_id)
    .bind(event_type)
    .bind(job_id)
    .bind(payload)
    .execute(pool)
    .await?;
    Ok(())
}

#[derive(Serialize)]
struct UsageSummaryResponse {
    events_last_24h: i64,
    events_last_7d: i64,
    /// Per-`event_type` counts in the rolling last 7 days (same window as `events_last_7d`).
    event_counts_last_7d: HashMap<String, i64>,
}

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/usage/summary", get(usage_summary))
}

async fn usage_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<UsageSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let row: (i64, i64) = sqlx::query_as(
        r#"
        SELECT
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '1 day'
            )::bigint,
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '7 days'
            )::bigint
        FROM app_usage_event
        WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let breakdown: Vec<(String, i64)> = sqlx::query_as(
        r#"
        SELECT event_type, COUNT(*)::bigint
        FROM app_usage_event
        WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '7 days'
        GROUP BY event_type
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let event_counts_last_7d: HashMap<String, i64> = breakdown.into_iter().collect();

    Ok(Json(UsageSummaryResponse {
        events_last_24h: row.0,
        events_last_7d: row.1,
        event_counts_last_7d,
    }))
}
