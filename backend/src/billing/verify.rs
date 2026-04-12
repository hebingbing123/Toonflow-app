//! Webhook 签名验证。
//!
//! 支持两种方案，根据存在的请求头选择：
//!
//! 1. **Toonflow 原生** (`X-Toonflow-Signature: sha256=<hex>`)：
//!    - **推荐（抗重放）**：同时发送 **`X-Toonflow-Timestamp: <unix_secs>`**，签名为
//!      `HMAC-SHA256(secret, "<unix_secs>." + raw_body)`（与 Stripe 负载形式一致），并校验时间窗
//!      **`BILLING_TOONFLOW_TOLERANCE_SECS`**（默认与 Stripe 相同 **300** 秒）。
//!    - **兼容旧客户端**：无时间戳头时，仍为 `HMAC-SHA256(secret, raw_body)`（可重放）。
//!    - 设 **`BILLING_TOONFLOW_REQUIRE_TIMESTAMP=1`** 则**仅允许**带时间戳的方案（拒绝纯 body 签名）。
//!
//! 2. **Stripe** (`Stripe-Signature: t=<unix>,v1=<hex>[,v1=<hex>...]`：
//!    Stripe 的签名负载方案：`HMAC-SHA256("<unix>.<raw_body>")`。
//!    容差窗口：`BILLING_STRIPE_TOLERANCE_SECS`（默认 300 秒）。
//!    要求 `BILLING_WEBHOOK_SECRET` 保存 Stripe 端点密钥（`whsec_...`）。
//!
//! 如果两个请求头都不存在 → `InvalidWebhookSignature`。

use axum::http::HeaderMap;
use hmac::{Hmac, Mac};
use sha2::Sha256;
use subtle::ConstantTimeEq;

use crate::error::ApiError;

pub(crate) type HmacSha256 = Hmac<Sha256>;

/// Default Stripe / Toonflow timestamp tolerance in seconds.
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

fn toonflow_tolerance_secs() -> u64 {
    std::env::var("BILLING_TOONFLOW_TOLERANCE_SECS")
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(DEFAULT_STRIPE_TOLERANCE_SECS)
}

fn toonflow_require_timestamp() -> bool {
    matches!(
        std::env::var("BILLING_TOONFLOW_REQUIRE_TIMESTAMP")
            .ok()
            .as_deref(),
        Some("1")
    )
}

fn now_unix_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// Verify `X-Toonflow-Signature: sha256=<hex>` (see module docs for timestamped vs legacy body MAC).
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

    let ts_header = headers
        .get("x-toonflow-timestamp")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty());

    if let Some(ts_str) = ts_header {
        let ts: u64 = ts_str
            .parse()
            .map_err(|_| ApiError::InvalidWebhookSignature)?;
        if now_unix_secs().abs_diff(ts) > toonflow_tolerance_secs() {
            return Err(ApiError::InvalidWebhookSignature);
        }
        let mut mac =
            HmacSha256::new_from_slice(secret).map_err(|_| ApiError::InvalidWebhookSignature)?;
        mac.update(ts_str.as_bytes());
        mac.update(b".");
        mac.update(body);
        let computed = mac.finalize().into_bytes();
        if !bool::from(computed.ct_eq(&expected)) {
            return Err(ApiError::InvalidWebhookSignature);
        }
        return Ok(());
    }

    if toonflow_require_timestamp() {
        return Err(ApiError::InvalidWebhookSignature);
    }

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
    use std::sync::{Mutex, OnceLock};

    use super::*;

    fn toonflow_env_lock() -> std::sync::MutexGuard<'static, ()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
            .lock()
            .expect("toonflow env test lock")
    }

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

    fn make_toonflow_timestamped_header(secret: &[u8], body: &[u8], ts: u64) -> HeaderMap {
        let ts_str = ts.to_string();
        let mut mac = HmacSha256::new_from_slice(secret).unwrap();
        mac.update(ts_str.as_bytes());
        mac.update(b".");
        mac.update(body);
        let hex = hex::encode(mac.finalize().into_bytes());
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-toonflow-signature",
            format!("sha256={hex}").parse().unwrap(),
        );
        headers.insert(
            "x-toonflow-timestamp",
            ts_str.parse().expect("numeric timestamp header"),
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
    fn toonflow_accepts_timestamped_signature_within_tolerance() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_ts_ok"}"#;
        let ts = now_unix_secs();
        let headers = make_toonflow_timestamped_header(secret, body, ts);
        assert!(verify_signature(secret, body, &headers).is_ok());
    }

    #[test]
    fn toonflow_rejects_timestamped_when_ts_stale() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_ts_stale"}"#;
        let headers = make_toonflow_timestamped_header(secret, body, 1_000_000);
        assert!(verify_signature(secret, body, &headers).is_err());
    }

    #[test]
    fn toonflow_timestamp_with_legacy_mac_fails() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_ts_bad_mac"}"#;
        let mut headers = make_toonflow_header(secret, body);
        headers.insert(
            "x-toonflow-timestamp",
            now_unix_secs().to_string().parse().unwrap(),
        );
        assert!(verify_signature(secret, body, &headers).is_err());
    }

    #[test]
    fn toonflow_require_timestamp_rejects_legacy_only() {
        let _lock = toonflow_env_lock();
        let prev = std::env::var("BILLING_TOONFLOW_REQUIRE_TIMESTAMP").ok();
        std::env::set_var("BILLING_TOONFLOW_REQUIRE_TIMESTAMP", "1");
        let secret = b"test-secret";
        let body = br#"{"id":"evt_legacy_blocked"}"#;
        let headers = make_toonflow_header(secret, body);
        let r = verify_signature(secret, body, &headers);
        match &prev {
            None => std::env::remove_var("BILLING_TOONFLOW_REQUIRE_TIMESTAMP"),
            Some(v) => std::env::set_var("BILLING_TOONFLOW_REQUIRE_TIMESTAMP", v),
        }
        assert!(
            r.is_err(),
            "legacy body-only must fail when require-timestamp is on"
        );
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
