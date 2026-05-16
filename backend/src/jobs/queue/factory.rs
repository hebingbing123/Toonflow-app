use sqlx::PgPool;

use super::pg::PgQueue;
use super::types::Queue;

/// Create appropriate queue backend based on environment.
/// - If `REDIS_URL` is set, try Redis first, fall back to PostgreSQL
/// - Otherwise, use PostgreSQL directly
pub async fn create_queue(pool: PgPool) -> anyhow::Result<Box<dyn Queue>> {
    // Check for Redis URL
    if let Ok(redis_url) = std::env::var("REDIS_URL") {
        match create_redis_queue(&redis_url, pool.clone()).await {
            Ok(queue) => {
                tracing::info!("Using Redis queue backend: {}", redis_url);
                return Ok(queue);
            }
            Err(e) => {
                tracing::warn!(
                    "Failed to connect to Redis ({}), falling back to PostgreSQL",
                    e
                );
            }
        }
    }

    tracing::info!("Using PostgreSQL queue backend");
    Ok(Box::new(PgQueue::new(pool)))
}

#[cfg(feature = "redis")]
async fn create_redis_queue(_redis_url: &str, _pool: PgPool) -> anyhow::Result<Box<dyn Queue>> {
    // Redis implementation would go here when redis feature is enabled
    // For now, return error to trigger fallback
    anyhow::bail!("Redis feature not enabled in this build")
}

#[cfg(not(feature = "redis"))]
async fn create_redis_queue(_redis_url: &str, _pool: PgPool) -> anyhow::Result<Box<dyn Queue>> {
    anyhow::bail!("Redis feature not compiled")
}
