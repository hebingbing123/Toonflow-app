//! M.1: Tests for platform callback security validation

use super::callback_config::upsert_platform_secret;
use super::callback_validation::{
    validate_callback, CallbackValidationConfig, ValidationError,
};
use axum::http::HeaderMap;
use chrono::{Duration, Utc};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use sqlx::PgPool;

type HmacSha256 = Hmac<Sha256>;

/// Helper to compute valid signature
fn compute_signature(secret: &str, timestamp: &str, body: &[u8]) -> String {
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes()).unwrap();
    let mut payload = timestamp.as_bytes().to_vec();
    payload.push(b'.');
    payload.extend_from_slice(body);
    mac.update(&payload);
    hex::encode(mac.finalize().into_bytes())
}

/// Helper to create valid headers
fn create_valid_headers(
    signature: &str,
    timestamp: &str,
    nonce: &str,
    callback_id: Option<&str>,
) -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert("x-platform-signature", signature.parse().unwrap());
    headers.insert("x-platform-timestamp", timestamp.parse().unwrap());
    headers.insert("x-platform-nonce", nonce.parse().unwrap());
    if let Some(id) = callback_id {
        headers.insert("x-callback-id", id.parse().unwrap());
    }
    headers
}

#[cfg(test)]
mod tests {
    use super::*;

    #[sqlx::test]
    async fn test_valid_callback(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key-12345";
        let body = b"test callback body";
        let timestamp = Utc::now().timestamp().to_string();
        let nonce = "unique-nonce-123";

        // Setup: insert platform secret
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        // Compute valid signature
        let signature = compute_signature(secret, &timestamp, body);

        // Create headers
        let headers = create_valid_headers(&signature, &timestamp, nonce, Some("cb_123"));

        // Validate
        let config = CallbackValidationConfig::default();
        let result =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;

        assert!(result.is_ok());
        let validated = result.unwrap();
        assert_eq!(validated.platform_id, platform_id);
        assert_eq!(validated.nonce, nonce);
        assert_eq!(validated.callback_id, Some("cb_123".to_string()));
        assert_eq!(validated.body, body);
    }

    #[sqlx::test]
    async fn test_missing_headers(pool: PgPool) {
        let platform_id = "test_platform";
        let body = b"test body";
        let headers = HeaderMap::new();
        let config = CallbackValidationConfig::default();

        let result =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;

        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            ValidationError::MissingHeader(_)
        ));
    }

    #[sqlx::test]
    async fn test_invalid_signature(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key";
        let body = b"test body";
        let timestamp = Utc::now().timestamp().to_string();
        let nonce = "nonce-456";

        // Setup
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        // Create headers with wrong signature
        let headers = create_valid_headers("invalid_signature", &timestamp, nonce, None);

        let config = CallbackValidationConfig::default();
        let result =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;

        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            ValidationError::InvalidSignature
        ));
    }

    #[sqlx::test]
    async fn test_timestamp_too_old(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key";
        let body = b"test body";
        // Timestamp from 10 minutes ago (beyond default 5 minute tolerance)
        let old_timestamp = (Utc::now() - Duration::seconds(600)).timestamp();
        let timestamp = old_timestamp.to_string();
        let nonce = "nonce-789";

        // Setup
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        let signature = compute_signature(secret, &timestamp, body);
        let headers = create_valid_headers(&signature, &timestamp, nonce, None);

        let config = CallbackValidationConfig::default();
        let result =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;

        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            ValidationError::TimestampTooOld
        ));
    }

    #[sqlx::test]
    async fn test_timestamp_in_future(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key";
        let body = b"test body";
        // Timestamp 1 minute in future (beyond clock skew tolerance)
        let future_timestamp = (Utc::now() + Duration::seconds(60)).timestamp();
        let timestamp = future_timestamp.to_string();
        let nonce = "nonce-future";

        // Setup
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        let signature = compute_signature(secret, &timestamp, body);
        let headers = create_valid_headers(&signature, &timestamp, nonce, None);

        let config = CallbackValidationConfig::default();
        let result =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;

        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            ValidationError::TimestampInFuture
        ));
    }

    #[sqlx::test]
    async fn test_nonce_replay_attack(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key";
        let body = b"test body";
        let timestamp = Utc::now().timestamp().to_string();
        let nonce = "replay-nonce";

        // Setup
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        let signature = compute_signature(secret, &timestamp, body);
        let headers = create_valid_headers(&signature, &timestamp, nonce, None);

        let config = CallbackValidationConfig::default();

        // First request should succeed
        let result1 =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;
        assert!(result1.is_ok());

        // Second request with same nonce should fail (replay attack)
        let result2 =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;
        assert!(result2.is_err());
        assert!(matches!(result2.unwrap_err(), ValidationError::NonceReplay));
    }

    #[sqlx::test]
    async fn test_different_platforms_different_nonces(pool: PgPool) {
        let platform1 = "platform1";
        let platform2 = "platform2";
        let secret = "shared-secret";
        let body = b"test body";
        let timestamp = Utc::now().timestamp().to_string();
        let nonce = "shared-nonce";

        // Setup both platforms
        upsert_platform_secret(&pool, platform1, secret)
            .await
            .unwrap();
        upsert_platform_secret(&pool, platform2, secret)
            .await
            .unwrap();

        let signature = compute_signature(secret, &timestamp, body);
        let headers = create_valid_headers(&signature, &timestamp, nonce, None);

        let config = CallbackValidationConfig::default();

        // Same nonce should work for different platforms
        let result1 =
            validate_callback(&pool, platform1, &headers, body.to_vec(), &config, None).await;
        assert!(result1.is_ok());

        let result2 =
            validate_callback(&pool, platform2, &headers, body.to_vec(), &config, None).await;
        assert!(result2.is_ok());
    }

    #[sqlx::test]
    async fn test_validation_with_enforcement_disabled(pool: PgPool) {
        let platform_id = "test_platform";
        let body = b"test body";
        let timestamp = Utc::now().timestamp().to_string();
        let nonce = "any-nonce";

        // Create headers with invalid signature
        let headers = create_valid_headers("invalid", &timestamp, nonce, None);

        // Disable enforcement
        let config = CallbackValidationConfig {
            enforce_signature: false,
            enforce_nonce: false,
            ..Default::default()
        };

        // Should succeed even with invalid signature when enforcement is off
        let result =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;
        assert!(result.is_ok());
    }

    #[sqlx::test]
    async fn test_custom_timestamp_tolerance(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key";
        let body = b"test body";
        // Timestamp 8 minutes ago
        let old_timestamp = (Utc::now() - Duration::seconds(480)).timestamp();
        let timestamp = old_timestamp.to_string();
        let nonce = "nonce-custom";

        // Setup
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        let signature = compute_signature(secret, &timestamp, body);
        let headers = create_valid_headers(&signature, &timestamp, nonce, None);

        // Default config (5 min) should fail
        let config_default = CallbackValidationConfig::default();
        let result_default = validate_callback(
            &pool,
            platform_id,
            &headers,
            body.to_vec(),
            &config_default,
            None,
        )
        .await;
        assert!(result_default.is_err());

        // Custom config (10 min) should succeed
        let config_custom = CallbackValidationConfig {
            timestamp_tolerance_secs: 600,
            ..Default::default()
        };
        let result_custom = validate_callback(
            &pool,
            platform_id,
            &headers,
            body.to_vec(),
            &config_custom,
            None,
        )
        .await;
        assert!(result_custom.is_ok());
    }

    #[sqlx::test]
    async fn test_audit_log_created(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key";
        let body = b"test body";
        let timestamp = Utc::now().timestamp().to_string();
        let nonce = "audit-nonce";

        // Setup
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        let signature = compute_signature(secret, &timestamp, body);
        let headers = create_valid_headers(&signature, &timestamp, nonce, Some("cb_audit"));

        let config = CallbackValidationConfig::default();
        let _ = validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;

        // Check audit log was created
        let audit_count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM app_publish_callback_audit WHERE platform_id = $1",
        )
        .bind(platform_id)
        .fetch_one(&pool)
        .await
        .unwrap();

        assert!(audit_count > 0);
    }

    #[sqlx::test]
    async fn test_invalid_nonce_format(pool: PgPool) {
        let platform_id = "test_platform";
        let secret = "test-secret-key";
        let body = b"test body";
        let timestamp = Utc::now().timestamp().to_string();
        let empty_nonce = "";

        // Setup
        upsert_platform_secret(&pool, platform_id, secret)
            .await
            .unwrap();

        let signature = compute_signature(secret, &timestamp, body);
        let headers = create_valid_headers(&signature, &timestamp, empty_nonce, None);

        let config = CallbackValidationConfig::default();
        let result =
            validate_callback(&pool, platform_id, &headers, body.to_vec(), &config, None).await;

        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            ValidationError::InvalidNonce(_)
        ));
    }
}
