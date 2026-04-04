//! Billing provider webhooks (§12 / §13): HMAC-verified ingestion + idempotent dedupe by provider event id.

use axum::body::Bytes;
use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::post;
use axum::{Json, Router};
use hmac::{Hmac, Mac};
use serde_json::{json, Value};
use sha2::Sha256;
use subtle::ConstantTimeEq;

use crate::error::ApiError;
use crate::state::AppState;

type HmacSha256 = Hmac<Sha256>;

fn billing_secret() -> Result<Vec<u8>, ApiError> {
    std::env::var("BILLING_WEBHOOK_SECRET")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.into_bytes())
        .ok_or(ApiError::WebhookNotConfigured)
}

/// Parse `X-Toonflow-Signature: sha256=<hex>` (constant-time compare to computed HMAC-SHA256 of raw body).
fn verify_signature(secret: &[u8], body: &[u8], headers: &HeaderMap) -> Result<(), ApiError> {
    let raw = headers
        .get("x-toonflow-signature")
        .and_then(|v| v.to_str().ok())
        .ok_or(ApiError::InvalidWebhookSignature)?;

    let hex_part = raw
        .trim()
        .strip_prefix("sha256=")
        .ok_or(ApiError::InvalidWebhookSignature)?;

    let expected_bytes =
        hex::decode(hex_part.trim()).map_err(|_| ApiError::InvalidWebhookSignature)?;

    let expected: [u8; 32] = expected_bytes
        .as_slice()
        .try_into()
        .map_err(|_| ApiError::InvalidWebhookSignature)?;

    let mut mac =
        HmacSha256::new_from_slice(secret).map_err(|_| ApiError::InvalidWebhookSignature)?;
    mac.update(body);
    let computed = mac.finalize().into_bytes();

    if !bool::from(computed.ct_eq(&expected)) {
        return Err(ApiError::InvalidWebhookSignature);
    }

    Ok(())
}

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/webhooks/billing", post(post_billing_webhook))
}

async fn post_billing_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> Result<Json<Value>, ApiError> {
    let secret = billing_secret()?;
    verify_signature(&secret, &body, &headers)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let v: Value = serde_json::from_slice(&body)
        .map_err(|_| ApiError::BadRequest("body must be valid JSON".into()))?;

    let provider_event_id = v
        .get("id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| {
            ApiError::BadRequest(
                "JSON body must include a non-empty string id for deduplication".into(),
            )
        })?;

    let inserted = sqlx::query_scalar::<_, i64>(
        r#"
        INSERT INTO app_billing_webhook_event (provider_event_id, payload)
        VALUES ($1, $2)
        ON CONFLICT (provider_event_id) DO NOTHING
        RETURNING id
        "#,
    )
    .bind(provider_event_id)
    .bind(&v)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(id) = inserted {
        return Ok(Json(json!({
            "received": true,
            "duplicate": false,
            "id": id,
        })));
    }

    Ok(Json(json!({
        "received": true,
        "duplicate": true,
    })))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verify_signature_accepts_matching_header() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_1","amount":100}"#;
        let mut mac = HmacSha256::new_from_slice(secret).unwrap();
        mac.update(body);
        let hex = hex::encode(mac.finalize().into_bytes());
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-toonflow-signature",
            format!("sha256={hex}").parse().unwrap(),
        );
        assert!(verify_signature(secret, body, &headers).is_ok());
    }

    #[test]
    fn verify_signature_rejects_wrong_mac() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_1"}"#;
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-toonflow-signature",
            "sha256=0000000000000000000000000000000000000000000000000000000000000000"
                .parse()
                .unwrap(),
        );
        assert!(verify_signature(secret, body, &headers).is_err());
    }
}
