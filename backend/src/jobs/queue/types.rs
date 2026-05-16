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

    /// Get queue stats (depths, claimable backlog, recent failures, kind distribution).
    async fn stats(&self) -> anyhow::Result<QueueStats>;
}

/// Queue statistics (PG `app_generation_job` aggregate).
#[derive(Debug, Clone)]
pub struct QueueStats {
    /// All rows with `status = 'queued'` (includes future `run_at_ms`).
    pub pending: i64,
    /// `queued` rows that the worker can claim now (`run_at_ms` absent or due).
    pub pending_claimable: i64,
    pub running: i64,
    pub dead: i64,
    /// `failed` rows touched in the last 24h (retry churn / incident signal).
    pub failed_last_24h: i64,
    /// Age in seconds of the oldest **claimable** queued job (`None` if none).
    pub oldest_claimable_queued_age_secs: Option<i64>,
    /// JSON object: `{ "<kind>": <count>, ... }` for up to 15 kinds among **all** queued rows.
    pub pending_by_kind_json: Value,
}
