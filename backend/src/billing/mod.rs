//! Billing provider webhooks (§12 / §13): HMAC-verified ingestion + idempotent dedupe by provider event id.
//! On first receipt, optional `user_id` + `plan_tier` upsert `app_user_profile`.

mod ingest;
mod verify;

use axum::body::Bytes;
use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::post;
use axum::{Json, Router};
use serde_json::{json, Value};

use crate::error::ApiError;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/webhooks/billing", post(post_billing_webhook))
}

async fn post_billing_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> Result<Json<Value>, ApiError> {
    let secret = verify::billing_secret()?;
    verify::verify_signature(&secret, &body, &headers)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let v: Value = serde_json::from_slice(&body)
        .map_err(|_| ApiError::BadRequest("body must be valid JSON".into()))?;

    match ingest::ingest_webhook(pool, &v).await? {
        None => Ok(Json(json!({
            "received": true,
            "duplicate": true,
        }))),
        Some((row_id, profile_updated)) => Ok(Json(json!({
            "received": true,
            "duplicate": false,
            "id": row_id,
            "profile_updated": profile_updated,
        }))),
    }
}
