//! M.1: Configuration for platform callback security
//!
//! This module provides utilities for managing platform callback secrets.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// Insert or update platform secret
pub async fn upsert_platform_secret(
    pool: &PgPool,
    platform_id: &str,
    secret_key: &str,
) -> Result<Uuid, ApiError> {
    let id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO app_publish_platform_secret (platform_id, secret_key, is_active)
        VALUES ($1, $2, true)
        ON CONFLICT (platform_id) 
        DO UPDATE SET 
            secret_key = EXCLUDED.secret_key,
            is_active = true,
            updated_at = NOW()
        RETURNING id
        "#,
    )
    .bind(platform_id)
    .bind(secret_key)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(id)
}

/// Deactivate platform secret (for key rotation)
pub async fn deactivate_platform_secret(
    pool: &PgPool,
    platform_id: &str,
) -> Result<bool, ApiError> {
    let result = sqlx::query(
        r#"
        UPDATE app_publish_platform_secret
        SET is_active = false,
            rotated_at = NOW(),
            updated_at = NOW()
        WHERE platform_id = $1 AND is_active = true
        "#,
    )
    .bind(platform_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(result.rows_affected() > 0)
}

/// Get active platform secret
pub async fn get_platform_secret(pool: &PgPool, platform_id: &str) -> Result<String, ApiError> {
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    secret.ok_or(ApiError::NotFound)
}

/// List all platform secrets (for admin purposes)
pub async fn list_platform_secrets(pool: &PgPool) -> Result<Vec<PlatformSecretInfo>, ApiError> {
    let rows: Vec<PlatformSecretInfo> = sqlx::query_as(
        r#"
        SELECT platform_id, is_active, created_at, updated_at, rotated_at
        FROM app_publish_platform_secret
        ORDER BY platform_id
        "#,
    )
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows)
}

#[derive(Debug, sqlx::FromRow)]
pub struct PlatformSecretInfo {
    pub platform_id: String,
    pub is_active: bool,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    pub rotated_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// Initialize default platform secrets (for development/testing)
///
/// WARNING: These are example secrets and should NOT be used in production!
/// In production, generate strong random secrets and store them securely.
pub async fn init_default_secrets(pool: &PgPool) -> Result<(), ApiError> {
    let platforms = vec![
        "douyin",
        "bilibili",
        "xiaohongshu",
        "weixin_channels",
        "kuaishou",
        "tiktok",
        "youtube_shorts",
        "instagram_reels",
        "facebook_reels",
    ];

    for platform_id in platforms {
        // Generate a random secret for each platform
        let secret = generate_random_secret();
        upsert_platform_secret(pool, platform_id, &secret).await?;
        tracing::info!(
            platform_id = platform_id,
            "Initialized callback secret (development only)"
        );
    }

    Ok(())
}

/// Generate a random secret key (32 bytes, hex-encoded)
fn generate_random_secret() -> String {
    use rand::Rng;
    let mut rng = rand::thread_rng();
    let bytes: Vec<u8> = (0..32).map(|_| rng.gen()).collect();
    hex::encode(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_random_secret() {
        let secret1 = generate_random_secret();
        let secret2 = generate_random_secret();

        // Should be 64 hex characters (32 bytes)
        assert_eq!(secret1.len(), 64);
        assert_eq!(secret2.len(), 64);

        // Should be different
        assert_ne!(secret1, secret2);

        // Should be valid hex
        assert!(hex::decode(&secret1).is_ok());
        assert!(hex::decode(&secret2).is_ok());
    }
}
