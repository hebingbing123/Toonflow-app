use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::Value;
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
