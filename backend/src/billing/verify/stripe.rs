use axum::http::HeaderMap;
use hmac::Mac;
use subtle::ConstantTimeEq;

use crate::error::ApiError;

use super::secret::stripe_tolerance_secs;
use super::HmacSha256;

/// Core Stripe verification with an explicit `now` timestamp (enables deterministic tests).
///
/// Format: `t=<unix_ts>,v1=<hex>[,v1=<hex>...]`
/// Signed payload: `"<unix_ts>.<raw_body>"`.
pub(super) fn verify_stripe_signature_at(
    secret: &[u8],
    body: &[u8],
    headers: &HeaderMap,
    now: u64,
) -> Result<(), ApiError> {
    let raw = headers
        .get("stripe-signature")
        .and_then(|v| v.to_str().ok())
        .ok_or(ApiError::InvalidWebhookSignature)?;

    let mut timestamp_str: Option<&str> = None;
    let mut v1_sigs: Vec<&str> = Vec::new();

    for part in raw.split(',') {
        let part = part.trim();
        if let Some(t) = part.strip_prefix("t=") {
            timestamp_str = Some(t.trim());
        } else if let Some(sig) = part.strip_prefix("v1=") {
            v1_sigs.push(sig.trim());
        }
    }

    let ts_str = timestamp_str.ok_or(ApiError::InvalidWebhookSignature)?;
    let ts: u64 = ts_str
        .parse()
        .map_err(|_| ApiError::InvalidWebhookSignature)?;

    let diff = now.abs_diff(ts);
    if diff > stripe_tolerance_secs() {
        return Err(ApiError::InvalidWebhookSignature);
    }

    if v1_sigs.is_empty() {
        return Err(ApiError::InvalidWebhookSignature);
    }

    let mut mac =
        HmacSha256::new_from_slice(secret).map_err(|_| ApiError::InvalidWebhookSignature)?;
    mac.update(ts_str.as_bytes());
    mac.update(b".");
    mac.update(body);
    let computed = mac.finalize().into_bytes();

    // Accept if any v1 signature matches (Stripe sends multiple during key rotation).
    for sig_hex in &v1_sigs {
        let Ok(sig_bytes) = hex::decode(sig_hex) else {
            continue;
        };
        let Ok(sig_arr): Result<[u8; 32], _> = sig_bytes.as_slice().try_into() else {
            continue;
        };
        if bool::from(computed.ct_eq(&sig_arr)) {
            return Ok(());
        }
    }

    Err(ApiError::InvalidWebhookSignature)
}
