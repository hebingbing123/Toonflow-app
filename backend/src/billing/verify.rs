//! HMAC-SHA256 verification for `X-Toonflow-Signature` and `BILLING_WEBHOOK_SECRET`.

use axum::http::HeaderMap;
use hmac::{Hmac, Mac};
use sha2::Sha256;
use subtle::ConstantTimeEq;

use crate::error::ApiError;

pub(crate) type HmacSha256 = Hmac<Sha256>;

pub(crate) fn billing_secret() -> Result<Vec<u8>, ApiError> {
    std::env::var("BILLING_WEBHOOK_SECRET")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.into_bytes())
        .ok_or(ApiError::WebhookNotConfigured)
}

/// Parse `X-Toonflow-Signature: sha256=<hex>` (constant-time compare to computed HMAC-SHA256 of raw body).
pub(crate) fn verify_signature(
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
