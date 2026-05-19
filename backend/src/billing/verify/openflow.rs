use axum::http::HeaderMap;
use hmac::Mac;
use subtle::ConstantTimeEq;

use crate::error::ApiError;

use super::secret::{now_unix_secs, openflow_tolerance_secs};
use super::HmacSha256;

/// Verify `X-Openflow-Signature: sha256=<hex>` with mandatory timestamped MAC.
pub(super) fn verify_openflow_signature(
    secret: &[u8],
    body: &[u8],
    headers: &HeaderMap,
) -> Result<(), ApiError> {
    let raw = headers
        .get("x-openflow-signature")
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

    let ts_str = headers
        .get("x-openflow-timestamp")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or(ApiError::InvalidWebhookSignature)?;

    let ts: u64 = ts_str
        .parse()
        .map_err(|_| ApiError::InvalidWebhookSignature)?;
    if now_unix_secs().abs_diff(ts) > openflow_tolerance_secs() {
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
    Ok(())
}
