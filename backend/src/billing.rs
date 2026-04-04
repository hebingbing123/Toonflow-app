//! Billing provider webhooks (§12 / §13): HMAC-verified ingestion + idempotent dedupe by provider event id.
//! On first receipt, optional `user_id` + `plan_tier` upsert `app_user_profile`.

use axum::body::Bytes;
use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::post;
use axum::{Json, Router};
use hmac::{Hmac, Mac};
use serde_json::{json, Value};
use sha2::Sha256;
use subtle::ConstantTimeEq;
use uuid::Uuid;

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

/// When `user_id` (UUID) and `plan_tier` (non-empty) are present, upsert profile (first successful webhook only).
async fn apply_plan_from_webhook_payload(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    v: &Value,
) -> Result<bool, sqlx::Error> {
    let Some(uid_str) = v.get("user_id").and_then(Value::as_str) else {
        return Ok(false);
    };
    let Ok(uid) = Uuid::parse_str(uid_str.trim()) else {
        tracing::warn!(user_id = %uid_str, "billing webhook: invalid user_id (skip profile upsert)");
        return Ok(false);
    };
    let Some(tier_raw) = v.get("plan_tier").and_then(Value::as_str) else {
        return Ok(false);
    };
    let tier: String = tier_raw.trim().chars().take(64).collect();
    if tier.is_empty() {
        return Ok(false);
    }

    let currency = v
        .get("billing_currency")
        .and_then(Value::as_str)
        .map(|s| s.trim().chars().take(16).collect::<String>())
        .filter(|s| !s.is_empty());
    let provider = v
        .get("billing_provider")
        .and_then(Value::as_str)
        .map(|s| s.trim().chars().take(64).collect::<String>())
        .filter(|s| !s.is_empty());

    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, plan_tier, billing_currency, billing_provider, updated_at)
        VALUES ($1, $2, $3, $4, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          plan_tier = EXCLUDED.plan_tier,
          billing_currency = COALESCE(EXCLUDED.billing_currency, app_user_profile.billing_currency),
          billing_provider = COALESCE(EXCLUDED.billing_provider, app_user_profile.billing_provider),
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(&tier)
    .bind(currency.as_deref())
    .bind(provider.as_deref())
    .execute(&mut **tx)
    .await?;

    Ok(true)
}

async fn ingest_webhook(pool: &sqlx::PgPool, v: &Value) -> Result<Option<(i64, bool)>, ApiError> {
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

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let inserted = sqlx::query_scalar::<_, i64>(
        r#"
        INSERT INTO app_billing_webhook_event (provider_event_id, payload)
        VALUES ($1, $2)
        ON CONFLICT (provider_event_id) DO NOTHING
        RETURNING id
        "#,
    )
    .bind(provider_event_id)
    .bind(v)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(row_id) = inserted else {
        tx.commit()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Ok(None);
    };

    let profile_updated = apply_plan_from_webhook_payload(&mut tx, v)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Some((row_id, profile_updated)))
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

    match ingest_webhook(pool, &v).await? {
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
