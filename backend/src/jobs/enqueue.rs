use axum::http::HeaderMap;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::metering::quota;
use crate::metering::usage;

use super::dto::JobRow;
use super::payload_project::{
    normalize_project_scope_in_job_payload, resolved_workspace_id_from_job_payload,
};
use super::{
    hydrate_job_row, merge_client_request_id_from_http_headers, merge_default_track_metadata,
};

fn client_request_id_from_payload(payload: &serde_json::Value) -> Option<&str> {
    payload
        .get("client_request_id")
        .or_else(|| payload.get("request_id"))
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
}

/// Enqueue **`queued`** job after quota check (no HTTP idempotency). Records **`generation_job.created`** usage.
///
/// When **`http_headers`** is **`Some`**, copies **`X-Request-Id`** into **`payload.client_request_id`**
/// if not already set (see **`merge_client_request_id_from_http_headers`**).
pub async fn enqueue_generation_job(
    pool: &PgPool,
    owner_user_id: Uuid,
    kind: &str,
    mut payload: serde_json::Value,
    http_headers: Option<&HeaderMap>,
) -> Result<JobRow, ApiError> {
    quota::check_daily_job_quota(pool, owner_user_id).await?;
    if let Some(headers) = http_headers {
        merge_client_request_id_from_http_headers(headers, &mut payload);
    }
    merge_default_track_metadata(kind, &mut payload);
    let resolved_workspace_id =
        normalize_project_scope_in_job_payload(pool, owner_user_id, &mut payload).await?;
    let mut row = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key)
        VALUES ($1, $2, $3, 'queued', NULL)
        RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(owner_user_id)
    .bind(kind)
    .bind(payload)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    hydrate_job_row(&mut row);

    if let Some(workspace_id) =
        resolved_workspace_id.or_else(|| resolved_workspace_id_from_job_payload(&row.payload))
    {
        tracing::info!(
            event = "generation_job_enqueued",
            user_id = %owner_user_id,
            job_id = %row.id,
            kind = %row.kind,
            workspace_id = %workspace_id,
            client_request_id = client_request_id_from_payload(&row.payload).unwrap_or(""),
            "generation job enqueued"
        );
    }

    if let Err(e) =
        usage::record_generation_job_created(pool, owner_user_id, row.id, &row.kind).await
    {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(row)
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
