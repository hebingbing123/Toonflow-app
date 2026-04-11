//! 队列抽象层，支持 PostgreSQL（默认）和 Redis（可选）后端。
#![allow(dead_code)]
//!
//! 提供统一的任务队列接口，自动回退：
//! - 如果设置了 `REDIS_URL` 且 Redis 可用，使用 Redis 进行更快的队列操作
//! - 否则回退到 PostgreSQL `FOR UPDATE SKIP LOCKED`（现有行为）

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{PgPool, Row};
use uuid::Uuid;

/// Job payload for queue operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JobPayload {
    pub kind: String,
    pub user_id: Uuid,
    pub payload: Value,
    pub priority: Option<i32>,
}

/// Queued job returned from dequeue.
#[derive(Debug, Clone)]
pub struct QueuedJob {
    pub id: Uuid,
    pub kind: String,
    pub user_id: Uuid,
    pub payload: Value,
}

/// Queue backend trait.
#[async_trait]
pub trait Queue: Send + Sync {
    /// Enqueue a job. Returns the job ID.
    async fn enqueue(&self, payload: JobPayload) -> anyhow::Result<Uuid>;

    /// Dequeue a job (blocking with timeout). Returns None if timeout.
    async fn dequeue(&self, timeout_secs: u64) -> anyhow::Result<Option<QueuedJob>>;

    /// Mark job as completed.
    async fn complete(&self, job_id: Uuid) -> anyhow::Result<()>;

    /// Mark job as failed with retry.
    async fn fail(&self, job_id: Uuid, error: String) -> anyhow::Result<()>;

    /// Get queue stats (pending, running, dead).
    async fn stats(&self) -> anyhow::Result<QueueStats>;
}

/// Queue statistics.
#[derive(Debug, Clone)]
pub struct QueueStats {
    pub pending: i64,
    pub running: i64,
    pub dead: i64,
}

// =============================================================================
// PostgreSQL Implementation (Default)
// =============================================================================

pub struct PgQueue {
    pool: PgPool,
}

impl PgQueue {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl Queue for PgQueue {
    async fn enqueue(&self, payload: JobPayload) -> anyhow::Result<Uuid> {
        let id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_generation_job (id, user_id, kind, payload, status, priority, created_at)
            VALUES ($1, $2, $3, $4, 'queued', $5, now())
            "#
        )
        .bind(id)
        .bind(payload.user_id)
        .bind(payload.kind)
        .bind(payload.payload)
        .bind(payload.priority.unwrap_or(0))
        .execute(&self.pool)
        .await?;
        Ok(id)
    }

    async fn dequeue(&self, _timeout_secs: u64) -> anyhow::Result<Option<QueuedJob>> {
        // Use FOR UPDATE SKIP LOCKED for efficient concurrent dequeuing
        let row = sqlx::query(
            r#"
            UPDATE app_generation_job
            SET status = 'running', updated_at = now()
            WHERE id = (
                SELECT id FROM app_generation_job
                WHERE status = 'queued'
                ORDER BY priority DESC, created_at ASC
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            )
            RETURNING id, kind, user_id, payload
            "#,
        )
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(|r| QueuedJob {
            id: r.get("id"),
            kind: r.get("kind"),
            user_id: r.get("user_id"),
            payload: r.get("payload"),
        }))
    }

    async fn complete(&self, job_id: Uuid) -> anyhow::Result<()> {
        sqlx::query(
            r#"
            UPDATE app_generation_job
            SET status = 'completed', updated_at = now(), finished_at = now()
            WHERE id = $1
            "#,
        )
        .bind(job_id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn fail(&self, job_id: Uuid, error: String) -> anyhow::Result<()> {
        sqlx::query(
            r#"
            UPDATE app_generation_job
            SET status = CASE 
                WHEN retry_count >= 3 THEN 'dead'
                ELSE 'failed'
            END,
            retry_count = retry_count + 1,
            last_error = $2,
            updated_at = now()
            WHERE id = $1
            "#,
        )
        .bind(job_id)
        .bind(error)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn stats(&self) -> anyhow::Result<QueueStats> {
        let row = sqlx::query(
            r#"
            SELECT 
                COUNT(*) FILTER (WHERE status = 'queued') as pending,
                COUNT(*) FILTER (WHERE status = 'running') as running,
                COUNT(*) FILTER (WHERE status = 'dead') as dead
            FROM app_generation_job
            "#,
        )
        .fetch_one(&self.pool)
        .await?;

        Ok(QueueStats {
            pending: row.get("pending"),
            running: row.get("running"),
            dead: row.get("dead"),
        })
    }
}

// =============================================================================
// Factory: Auto-detect backend from environment
// =============================================================================

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
