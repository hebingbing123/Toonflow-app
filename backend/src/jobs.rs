use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, FromRow, Serialize)]
pub struct JobRow {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub kind: String,
    pub status: String,
    pub payload: serde_json::Value,
    pub result: Option<serde_json::Value>,
    pub error_message: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CreateJobBody {
    pub kind: String,
    #[serde(default)]
    pub payload: serde_json::Value,
}

/// WebSocket envelope (`docs/websocket-events.md`): full job row as `payload`.
pub fn envelope_generation_job_updated(row: &JobRow) -> String {
    let v = json!({
        "type": "generation.job.updated",
        "schema_version": 1,
        "payload": row,
    });
    serde_json::to_string(&v).expect("JobRow serializes to JSON")
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/jobs", get(list_jobs).post(create_job))
        .route("/api/v1/jobs/{id}", get(get_job))
}

async fn list_jobs(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<JobRow>>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;
    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT id, owner_user_id, kind, status, payload, result, error_message, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        LIMIT 100
        "#,
    )
    .bind(uid)
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
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;
    let kind = body.kind.trim();
    if kind.is_empty() {
        return Err(ApiError::BadRequest("kind must not be empty".into()));
    }
    let row = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status)
        VALUES ($1, $2, $3, 'queued')
        RETURNING id, owner_user_id, kind, status, payload, result, error_message, created_at, updated_at
        "#,
    )
    .bind(uid)
    .bind(kind)
    .bind(body.payload)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(row))
}

async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;
    let row = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT id, owner_user_id, kind, status, payload, result, error_message, created_at, updated_at
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
