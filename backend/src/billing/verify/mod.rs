//! Webhook 签名验证。
//!
//! 支持两种方案，根据存在的请求头选择：
//!
//! 1. **Toonflow 原生** (`X-Toonflow-Signature: sha256=<hex>`)：
//!    - 必须同时发送 **`X-Toonflow-Timestamp: <unix_secs>`**，签名为
//!      `HMAC-SHA256(secret, "<unix_secs>." + raw_body)`（与 Stripe 负载形式一致），并校验时间窗
//!      **`BILLING_TOONFLOW_TOLERANCE_SECS`**（默认与 Stripe 相同 **300** 秒）。
//!
//! 2. **Stripe** (`Stripe-Signature: t=<unix>,v1=<hex>[,v1=<hex>...]`：
//!    Stripe 的签名负载方案：`HMAC-SHA256("<unix>.<raw_body>")`。
//!    容差窗口：`BILLING_STRIPE_TOLERANCE_SECS`（默认 300 秒）。
//!    要求 `BILLING_WEBHOOK_SECRET` 保存 Stripe 端点密钥（`whsec_...`）。
//!
//! 如果两个请求头都不存在 → `InvalidWebhookSignature`。

use axum::http::HeaderMap;
use hmac::Hmac;
use sha2::Sha256;

mod secret;
mod stripe;
mod toonflow;

pub(crate) type HmacSha256 = Hmac<Sha256>;

pub(crate) use secret::billing_secret;

/// Verify the webhook signature using whichever scheme header is present.
///
/// Checks `Stripe-Signature` first (more specific), then `X-Toonflow-Signature`.
pub(crate) fn verify_signature(
    secret: &[u8],
    body: &[u8],
    headers: &HeaderMap,
) -> Result<(), crate::error::ApiError> {
    if headers.contains_key("stripe-signature") {
        return stripe::verify_stripe_signature_at(secret, body, headers, secret::now_unix_secs());
    }
    toonflow::verify_toonflow_signature(secret, body, headers)
}

#[cfg(test)]
mod tests {
    use axum::http::HeaderMap;
    use hmac::Mac;

    use super::secret::{now_unix_secs, DEFAULT_STRIPE_TOLERANCE_SECS};
    use super::stripe::verify_stripe_signature_at;
    use super::verify_signature;
    use super::HmacSha256;

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
        let headers = make_toonflow_timestamped_header(secret, body, now_unix_secs());
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
    fn toonflow_timestamp_with_body_only_mac_fails() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_ts_bad_mac"}"#;
        let mut mac = HmacSha256::new_from_slice(secret).unwrap();
        mac.update(body);
        let hex = hex::encode(mac.finalize().into_bytes());
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-toonflow-signature",
            format!("sha256={hex}").parse().unwrap(),
        );
        headers.insert(
            "x-toonflow-timestamp",
            now_unix_secs().to_string().parse().unwrap(),
        );
        assert!(verify_signature(secret, body, &headers).is_err());
    }

    #[test]
    fn toonflow_rejects_missing_timestamp() {
        let secret = b"test-secret";
        let body = br#"{"id":"evt_missing_ts"}"#;
        let mut mac = HmacSha256::new_from_slice(secret).unwrap();
        mac.update(body);
        let hex = hex::encode(mac.finalize().into_bytes());
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-toonflow-signature",
            format!("sha256={hex}").parse().unwrap(),
        );
        assert!(verify_signature(secret, body, &headers).is_err());
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
