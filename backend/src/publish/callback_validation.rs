//! M.1: Platform callback security validation (signature/timestamp/nonce)
//!
//! This module provides comprehensive security validation for platform callbacks:
//! - HMAC-SHA256 signature verification
//! - Timestamp validation (prevent replay of old callbacks)
//! - Nonce validation (prevent replay attacks)
//!
//! ## Security Model
//!
//! Each platform has a secret key stored in `app_publish_platform_secret`.
//! Callbacks must include:
//! - `X-Platform-Signature`: HMAC-SHA256(secret, timestamp + "." + body)
//! - `X-Platform-Timestamp`: Unix timestamp (seconds)
//! - `X-Platform-Nonce`: Unique nonce for this request
//!
//! Validation steps:
//! 1. Extract and validate headers
//! 2. Check timestamp is within acceptable window (default: 5 minutes)
//! 3. Check nonce hasn't been used before
//! 4. Verify HMAC signature
//! 5. Record nonce to prevent replay
//! 6. Audit the validation result

use axum::http::HeaderMap;
use chrono::{DateTime, Duration, Utc};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use sqlx::PgPool;

use crate::error::ApiError;

type HmacSha256 = Hmac<Sha256>;

/// Configuration for callback validation
#[derive(Debug, Clone)]
pub struct CallbackValidationConfig {
    /// Maximum age of callback timestamp (default: 5 minutes)
    pub timestamp_tolerance_secs: i64,
    /// Whether to enforce nonce validation (default: true)
    pub enforce_nonce: bool,
    /// Whether to enforce signature validation (default: true)
    pub enforce_signature: bool,
}

impl Default for CallbackValidationConfig {
    fn default() -> Self {
        Self {
            timestamp_tolerance_secs: 300, // 5 minutes
            enforce_nonce: true,
            enforce_signature: true,
        }
    }
}

/// Validated callback request
#[derive(Debug)]
pub struct ValidatedCallback {
    pub platform_id: String,
    pub callback_id: Option<String>,
    pub timestamp: DateTime<Utc>,
    pub nonce: String,
    pub body: Vec<u8>,
}

/// Validation error types
#[derive(Debug)]
pub enum ValidationError {
    MissingHeader(&'static str),
    InvalidTimestamp(String),
    TimestampTooOld,
    TimestampInFuture,
    InvalidSignature,
    NonceReplay,
    DatabaseError(String),
    InvalidNonce(String),
}

impl From<ValidationError> for ApiError {
    fn from(err: ValidationError) -> Self {
        match err {
            ValidationError::MissingHeader(h) => {
                ApiError::BadRequest(format!("Missing required header: {}", h))
            }
            ValidationError::InvalidTimestamp(msg) => {
                ApiError::BadRequest(format!("Invalid timestamp: {}", msg))
            }
            ValidationError::TimestampTooOld => {
                ApiError::BadRequest("Callback timestamp too old".to_string())
            }
            ValidationError::TimestampInFuture => {
                ApiError::BadRequest("Callback timestamp in future".to_string())
            }
            ValidationError::InvalidSignature => ApiError::Unauthorized,
            ValidationError::NonceReplay => {
                ApiError::BadRequest("Nonce already used (replay attack)".to_string())
            }
            ValidationError::DatabaseError(msg) => ApiError::DatabaseError(msg),
            ValidationError::InvalidNonce(msg) => {
                ApiError::BadRequest(format!("Invalid nonce: {}", msg))
            }
        }
    }
}

/// Extract callback headers from request
fn extract_headers(
    headers: &HeaderMap,
) -> Result<(String, String, String, Option<String>), ValidationError> {
    let signature = headers
        .get("x-platform-signature")
        .and_then(|v| v.to_str().ok())
        .ok_or(ValidationError::MissingHeader("X-Platform-Signature"))?
        .to_string();

    let timestamp = headers
        .get("x-platform-timestamp")
        .and_then(|v| v.to_str().ok())
        .ok_or(ValidationError::MissingHeader("X-Platform-Timestamp"))?
        .to_string();

    let nonce = headers
        .get("x-platform-nonce")
        .and_then(|v| v.to_str().ok())
        .ok_or(ValidationError::MissingHeader("X-Platform-Nonce"))?
        .to_string();

    let callback_id = headers
        .get("x-callback-id")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    Ok((signature, timestamp, nonce, callback_id))
}

/// Validate timestamp is within acceptable window
fn validate_timestamp(
    timestamp_str: &str,
    config: &CallbackValidationConfig,
) -> Result<DateTime<Utc>, ValidationError> {
    let timestamp_secs: i64 = timestamp_str
        .parse()
        .map_err(|_| ValidationError::InvalidTimestamp("Not a valid integer".to_string()))?;

    let timestamp = DateTime::from_timestamp(timestamp_secs, 0)
        .ok_or_else(|| ValidationError::InvalidTimestamp("Timestamp out of range".to_string()))?;

    let now = Utc::now();
    let age = now.signed_duration_since(timestamp);
    let tolerance = Duration::seconds(config.timestamp_tolerance_secs);

    // Check if timestamp is too old
    if age > tolerance {
        return Err(ValidationError::TimestampTooOld);
    }

    // Check if timestamp is in the future (allow small clock skew)
    if age < Duration::seconds(-30) {
        return Err(ValidationError::TimestampInFuture);
    }

    Ok(timestamp)
}

/// Validate nonce hasn't been used before
async fn validate_nonce(
    pool: &PgPool,
    platform_id: &str,
    nonce: &str,
    _timestamp: DateTime<Utc>,
    config: &CallbackValidationConfig,
) -> Result<(), ValidationError> {
    if !config.enforce_nonce {
        return Ok(());
    }

    // Check nonce format (must be non-empty and reasonable length)
    if nonce.is_empty() || nonce.len() > 256 {
        return Err(ValidationError::InvalidNonce(
            "Nonce must be 1-256 characters".to_string(),
        ));
    }

    // Check if nonce already exists
    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM app_publish_callback_nonce
            WHERE nonce = $1 AND platform_id = $2 AND expires_at > NOW()
        )
        "#,
    )
    .bind(nonce)
    .bind(platform_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ValidationError::DatabaseError(e.to_string()))?;

    if exists {
        return Err(ValidationError::NonceReplay);
    }

    Ok(())
}

/// Record nonce to prevent future replay
async fn record_nonce(
    pool: &PgPool,
    platform_id: &str,
    nonce: &str,
    timestamp: DateTime<Utc>,
    config: &CallbackValidationConfig,
) -> Result<(), ValidationError> {
    if !config.enforce_nonce {
        return Ok(());
    }

    // Nonce expires after timestamp tolerance window
    let expires_at = timestamp + Duration::seconds(config.timestamp_tolerance_secs);

    sqlx::query(
        r#"
        INSERT INTO app_publish_callback_nonce 
            (nonce, platform_id, callback_timestamp, expires_at)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (nonce, platform_id) DO NOTHING
        "#,
    )
    .bind(nonce)
    .bind(platform_id)
    .bind(timestamp)
    .bind(expires_at)
    .execute(pool)
    .await
    .map_err(|e| ValidationError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// Fetch platform secret key
async fn fetch_platform_secret(
    pool: &PgPool,
    platform_id: &str,
) -> Result<String, ValidationError> {
    let secret: Option<String> = sqlx::query_scalar(
        r#"
        SELECT secret_key FROM app_publish_platform_secret
        WHERE platform_id = $1 AND is_active = true
        LIMIT 1
        "#,
    )
    .bind(platform_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ValidationError::DatabaseError(e.to_string()))?;

    secret.ok_or_else(|| {
        ValidationError::DatabaseError(format!("No active secret for platform: {}", platform_id))
    })
}

/// Verify HMAC-SHA256 signature
fn verify_signature(
    secret: &str,
    timestamp: &str,
    body: &[u8],
    signature_hex: &str,
) -> Result<(), ValidationError> {
    // Construct signed payload: timestamp + "." + body
    let mut payload = timestamp.as_bytes().to_vec();
    payload.push(b'.');
    payload.extend_from_slice(body);

    // Compute HMAC
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
        .map_err(|_| ValidationError::InvalidSignature)?;
    mac.update(&payload);
    let expected = mac.finalize().into_bytes();

    // Decode provided signature
    let provided = hex::decode(signature_hex).map_err(|_| ValidationError::InvalidSignature)?;

    // Constant-time comparison
    if provided.len() != expected.len() {
        return Err(ValidationError::InvalidSignature);
    }

    let mut diff = 0u8;
    for (a, b) in provided.iter().zip(expected.iter()) {
        diff |= a ^ b;
    }

    if diff == 0 {
        Ok(())
    } else {
        Err(ValidationError::InvalidSignature)
    }
}

/// Audit callback validation result
#[allow(clippy::too_many_arguments)]
async fn audit_callback(
    pool: &PgPool,
    platform_id: &str,
    callback_id: Option<&str>,
    validation_status: &str,
    headers: &HeaderMap,
    body_hash: &str,
    error_details: Option<&str>,
    source_ip: Option<&str>,
) -> Result<(), ValidationError> {
    // Sanitize headers (remove sensitive data)
    let sanitized_headers = serde_json::json!({
        "x-platform-timestamp": headers.get("x-platform-timestamp")
            .and_then(|v| v.to_str().ok()),
        "x-platform-nonce": headers.get("x-platform-nonce")
            .and_then(|v| v.to_str().ok())
            .map(|s| if s.len() > 16 { format!("{}...", &s[..16]) } else { s.to_string() }),
        "x-callback-id": headers.get("x-callback-id")
            .and_then(|v| v.to_str().ok()),
        "content-type": headers.get("content-type")
            .and_then(|v| v.to_str().ok()),
    });

    sqlx::query(
        r#"
        INSERT INTO app_publish_callback_audit
            (platform_id, callback_id, validation_status, request_headers, 
             body_hash, error_details, source_ip)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(platform_id)
    .bind(callback_id)
    .bind(validation_status)
    .bind(sanitized_headers)
    .bind(body_hash)
    .bind(error_details)
    .bind(source_ip)
    .execute(pool)
    .await
    .map_err(|e| ValidationError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// Validate platform callback request
///
/// This is the main entry point for callback validation.
/// It performs all security checks and returns a validated callback.
pub async fn validate_callback(
    pool: &PgPool,
    platform_id: &str,
    headers: &HeaderMap,
    body: Vec<u8>,
    config: &CallbackValidationConfig,
    source_ip: Option<&str>,
) -> Result<ValidatedCallback, ValidationError> {
    // Compute body hash for audit
    let body_hash = {
        use sha2::Digest;
        let mut hasher = sha2::Sha256::new();
        hasher.update(&body);
        hex::encode(hasher.finalize())
    };

    // Extract headers
    let (signature, timestamp_str, nonce, callback_id) = match extract_headers(headers) {
        Ok(h) => h,
        Err(e) => {
            let _ = audit_callback(
                pool,
                platform_id,
                None,
                "missing_headers",
                headers,
                &body_hash,
                Some(&format!("{:?}", e)),
                source_ip,
            )
            .await;
            return Err(e);
        }
    };

    // Validate timestamp
    let timestamp = match validate_timestamp(&timestamp_str, config) {
        Ok(ts) => ts,
        Err(e) => {
            let _ = audit_callback(
                pool,
                platform_id,
                callback_id.as_deref(),
                "invalid_timestamp",
                headers,
                &body_hash,
                Some(&format!("{:?}", e)),
                source_ip,
            )
            .await;
            return Err(e);
        }
    };

    // Validate nonce (check for replay)
    if let Err(e) = validate_nonce(pool, platform_id, &nonce, timestamp, config).await {
        let _ = audit_callback(
            pool,
            platform_id,
            callback_id.as_deref(),
            "replay_attack",
            headers,
            &body_hash,
            Some(&format!("{:?}", e)),
            source_ip,
        )
        .await;
        return Err(e);
    }

    // Verify signature
    if config.enforce_signature {
        let secret = match fetch_platform_secret(pool, platform_id).await {
            Ok(s) => s,
            Err(e) => {
                let _ = audit_callback(
                    pool,
                    platform_id,
                    callback_id.as_deref(),
                    "secret_not_found",
                    headers,
                    &body_hash,
                    Some(&format!("{:?}", e)),
                    source_ip,
                )
                .await;
                return Err(e);
            }
        };

        if let Err(e) = verify_signature(&secret, &timestamp_str, &body, &signature) {
            let _ = audit_callback(
                pool,
                platform_id,
                callback_id.as_deref(),
                "invalid_signature",
                headers,
                &body_hash,
                Some(&format!("{:?}", e)),
                source_ip,
            )
            .await;
            return Err(e);
        }
    }

    // Record nonce to prevent replay
    if let Err(e) = record_nonce(pool, platform_id, &nonce, timestamp, config).await {
        let _ = audit_callback(
            pool,
            platform_id,
            callback_id.as_deref(),
            "nonce_record_failed",
            headers,
            &body_hash,
            Some(&format!("{:?}", e)),
            source_ip,
        )
        .await;
        return Err(e);
    }

    // Audit successful validation
    let _ = audit_callback(
        pool,
        platform_id,
        callback_id.as_deref(),
        "valid",
        headers,
        &body_hash,
        None,
        source_ip,
    )
    .await;

    Ok(ValidatedCallback {
        platform_id: platform_id.to_string(),
        callback_id,
        timestamp,
        nonce,
        body,
    })
}

/// Cleanup expired nonces (should be called periodically)
pub async fn cleanup_expired_nonces(pool: &PgPool) -> Result<u64, sqlx::Error> {
    let result = sqlx::query("SELECT cleanup_expired_callback_nonces()")
        .execute(pool)
        .await?;

    Ok(result.rows_affected())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_timestamp_validation() {
        let config = CallbackValidationConfig::default();

        // Valid timestamp (now)
        let now = Utc::now().timestamp();
        assert!(validate_timestamp(&now.to_string(), &config).is_ok());

        // Old timestamp (beyond tolerance)
        let old = (Utc::now() - Duration::seconds(400)).timestamp();
        assert!(matches!(
            validate_timestamp(&old.to_string(), &config),
            Err(ValidationError::TimestampTooOld)
        ));

        // Future timestamp
        let future = (Utc::now() + Duration::seconds(60)).timestamp();
        assert!(matches!(
            validate_timestamp(&future.to_string(), &config),
            Err(ValidationError::TimestampInFuture)
        ));

        // Invalid format
        assert!(matches!(
            validate_timestamp("not-a-number", &config),
            Err(ValidationError::InvalidTimestamp(_))
        ));
    }

    #[test]
    fn test_signature_verification() {
        let secret = "test-secret-key";
        let timestamp = "1234567890";
        let body = b"test body content";

        // Compute valid signature
        let mut mac = HmacSha256::new_from_slice(secret.as_bytes()).unwrap();
        let mut payload = timestamp.as_bytes().to_vec();
        payload.push(b'.');
        payload.extend_from_slice(body);
        mac.update(&payload);
        let valid_sig = hex::encode(mac.finalize().into_bytes());

        // Valid signature should pass
        assert!(verify_signature(secret, timestamp, body, &valid_sig).is_ok());

        // Invalid signature should fail
        assert!(matches!(
            verify_signature(secret, timestamp, body, "invalid"),
            Err(ValidationError::InvalidSignature)
        ));

        // Wrong secret should fail
        assert!(matches!(
            verify_signature("wrong-secret", timestamp, body, &valid_sig),
            Err(ValidationError::InvalidSignature)
        ));
    }

    #[test]
    fn test_extract_headers() {
        let mut headers = HeaderMap::new();
        headers.insert("x-platform-signature", "abc123".parse().unwrap());
        headers.insert("x-platform-timestamp", "1234567890".parse().unwrap());
        headers.insert("x-platform-nonce", "nonce123".parse().unwrap());

        let result = extract_headers(&headers);
        assert!(result.is_ok());
        let (sig, ts, nonce, _) = result.unwrap();
        assert_eq!(sig, "abc123");
        assert_eq!(ts, "1234567890");
        assert_eq!(nonce, "nonce123");
    }

    #[test]
    fn test_extract_headers_missing() {
        let headers = HeaderMap::new();
        let result = extract_headers(&headers);
        assert!(matches!(result, Err(ValidationError::MissingHeader(_))));
    }
}
