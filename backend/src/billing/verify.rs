//! Webhook signature verification.
//!
//! Supports two schemes, selected by which header is present:
//!
//! 1. **Toonflow native** (`X-Toonflow-Signature: sha256=<hex>`):
//!    HMAC-SHA256 of raw body with `BILLING_WEBHOOK_SECRET`.
//!
//! 2. **Stripe** (`Stripe-Signature: t=<unix>,v1=<hex>[,v1=<hex>...]`):
//!    Stripe's signed-payload scheme: `HMAC-SHA256("<unix>.<raw_body>")`.
//!    Tolerance window: `BILLING_STRIPE_TOLERANCE_SECS` (default 300 s).
//!    Requires `BILLING_WEBHOOK_SECRET` to hold the Stripe endpoint secret (`whsec_...`).
//!
//! If neither header is present → `InvalidWebhookSignature`.

use axum::http::HeaderMap;
use hmac::{Hmac, Mac};
use sha2::Sha256;
use subtle::ConstantTimeEq;

use crate::error::ApiError;

pub(crate) type HmacSha256 = Hmac<Sha256>;

/// Default Stripe timestamp tolerance in seconds.
const DEFAULT_STRIPE_TOLERANCE_SECS: u64 = 300;

pub(crate) fn billing_secret() -> Result<Vec<u8>, ApiError> {
    std::env::var("BILLING_WEBHOOK_SECRET")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.into_bytes())
        .ok_or(ApiError::WebhookNotConfigured)
}

fn stripe_tolerance_secs() -> u64 {
    std::env::var("BILLING_STRIPE_TOLERANCE_SECS")
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(DEFAULT_STRIPE_TOLERANCE_SECS)
}

fn now_unix_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// Verify `X-Toonflow-Signature: sha256=<hex>` (constant-time HMAC-SHA256 of raw body).
fn verify_toonflow_signature(
    secret: &[u8],
    body: &[u8],
    headers: &HeaderMap,
) -> Result<(), ApiError> {
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

/// Core Stripe verification with an explicit `now` timestamp (enables deterministic tests).
///
/// Format: `t=<unix_ts>,v1=<hex>[,v1=<hex>...]`
/// Signed payload: `"<unix_ts>.<raw_body>"`.
fn verify_stripe_signature_at(
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

/// Verify the webhook signature using whichever scheme header is present.
///
/// Checks `Stripe-Signature` first (more specific), then `X-Toonflow-Signature`.
pub(crate) fn verify_signature(
    secret: &[u8],
    body: &[u8],
    headers: &HeaderMap,
) -> Result<(), ApiError> {
    if headers.contains_key("stripe-signature") {
        return verify_stripe_signature_at(secret, body, headers, now_unix_secs());
    }
    verify_toonflow_signature(secret, body, headers)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_toonflow_header(secret: &[u8], body: &[u8]) -> HeaderMap {
        let mut mac = HmacSha256::new_from_slice(secret).unwrap();
        mac.update(body);
        let hex = hex::encode(mac.finalize().into_bytes());
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-toonflow-signature",
            format!("sha256={hex}").parse().unwrap(),
        );
        headers
    }

    fn make_stripe_header(secret: &[u8], body: &[u8], ts: u64) -> HeaderMap {
        let ts_str = ts.to_string();
        let mut mac = HmacSha256::new_from_slice(secret).unwrap();
        mac.update(ts_str.as_bytes());
        mac.update(b".");
        mac.update(body);
        let hex = hex::encode(mac.finalize().into_bytes());
        let mut headers = HeaderMap::new();
        headers.insert(
            "stripe-signature",
            format!("t={ts_str},v1={hex}").parse().unwrap(),
        );
        headers
    }

    #[test]
    fn toonflow_accepts_matching_header() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_1","amount":100}"#;
        let headers = make_toonflow_header(secret, body);
        assert!(verify_signature(secret, body, &headers).is_ok());
    }

    #[test]
    fn toonflow_rejects_wrong_mac() {
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

    #[test]
    fn stripe_accepts_valid_signature_within_tolerance() {
        let secret = b"whsec_test";
        let body = br#"{"id":"evt_stripe_1"}"#;
        let ts: u64 = 1_700_000_000;
        let headers = make_stripe_header(secret, body, ts);
        // now == ts → diff = 0, well within tolerance
        let result = verify_stripe_signature_at(secret, body, &headers, ts);
        assert!(result.is_ok(), "expected ok, got {result:?}");
    }

    #[test]
    fn stripe_rejects_expired_timestamp() {
        let secret = b"whsec_test";
        let body = br#"{"id":"evt_stripe_2"}"#;
        let ts: u64 = 1_700_000_000;
        let now = ts + DEFAULT_STRIPE_TOLERANCE_SECS + 1;
        let headers = make_stripe_header(secret, body, ts);
        let result = verify_stripe_signature_at(secret, body, &headers, now);
        assert!(result.is_err(), "expected err for expired ts");
    }

    #[test]
    fn stripe_rejects_wrong_signature() {
        let secret = b"whsec_test";
        let body = br#"{"id":"evt_stripe_3"}"#;
        let ts: u64 = 1_700_000_000;
        let mut headers = HeaderMap::new();
        headers.insert(
            "stripe-signature",
            format!("t={ts},v1=0000000000000000000000000000000000000000000000000000000000000000")
                .parse()
                .unwrap(),
        );
        let result = verify_stripe_signature_at(secret, body, &headers, ts);
        assert!(result.is_err(), "expected err for wrong sig");
    }

    #[test]
    fn stripe_accepts_multiple_v1_sigs_when_one_matches() {
        let secret = b"whsec_test";
        let body = br#"{"id":"evt_stripe_4"}"#;
        let ts: u64 = 1_700_000_000;
        let ts_str = ts.to_string();
        let mut mac = HmacSha256::new_from_slice(secret).unwrap();
        mac.update(ts_str.as_bytes());
        mac.update(b".");
        mac.update(body);
        let good_hex = hex::encode(mac.finalize().into_bytes());
        let mut headers = HeaderMap::new();
        // First v1 is wrong, second is correct (key rotation scenario).
        headers.insert(
            "stripe-signature",
            format!("t={ts_str},v1=0000000000000000000000000000000000000000000000000000000000000000,v1={good_hex}")
                .parse()
                .unwrap(),
        );
        let result = verify_stripe_signature_at(secret, body, &headers, ts);
        assert!(result.is_ok(), "expected ok when second v1 matches");
    }

    #[test]
    fn no_signature_header_returns_error() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_1"}"#;
        let headers = HeaderMap::new();
        assert!(verify_signature(secret, body, &headers).is_err());
    }
}
