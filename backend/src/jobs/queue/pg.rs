use async_trait::async_trait;
use serde_json::{json, Map, Value};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use super::types::{JobPayload, Queue, QueueStats, QueuedJob};

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
    /// **DEPRECATED / UNUSED**: This enqueue method is not called anywhere in the codebase.
    ///
    /// For job creation, use:
    /// - `jobs::enqueue_generation_job` (primary, with workspace_id resolution)
    /// - `jobs::handlers::mutate::create::create_job` (HTTP endpoint)
    ///
    /// This method is kept for the `Queue` trait implementation, but the INSERT statement
    /// is outdated (missing `workspace_id` column, uses old `user_id` instead of `owner_user_id`).
    ///
    /// **Task 2.1 Audit**: Confirmed via grep that `.enqueue()` is never called.
    /// Only `PgQueue::stats()` is used (for queue metrics).
    ///
    /// TODO: Consider removing this method or updating to match current schema in future cleanup.
    async fn enqueue(&self, payload: JobPayload) -> anyhow::Result<Uuid> {
        let id = Uuid::new_v4();
        // WARNING: This INSERT is outdated and missing workspace_id column
        // Do not use this method - use jobs::enqueue_generation_job instead
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
            WITH claimable AS (
                SELECT id, created_at
                FROM app_generation_job
                WHERE status = 'queued'
                  AND (
                    payload->>'run_at_ms' IS NULL
                    OR (
                      (payload->>'run_at_ms') ~ '^[0-9]+$'
                      AND (payload->>'run_at_ms')::bigint <= (EXTRACT(EPOCH FROM NOW()) * 1000)::bigint
                    )
                  )
            )
            SELECT
              (SELECT COUNT(*)::bigint FROM app_generation_job WHERE status = 'queued') AS pending,
              (SELECT COUNT(*)::bigint FROM claimable) AS pending_claimable,
              (SELECT COUNT(*)::bigint FROM app_generation_job WHERE status = 'running') AS running,
              (SELECT COUNT(*)::bigint FROM app_generation_job WHERE status = 'dead') AS dead,
              (
                SELECT COUNT(*)::bigint
                FROM app_generation_job
                WHERE status = 'failed'
                  AND updated_at >= NOW() - INTERVAL '24 hours'
              ) AS failed_last_24h,
              (
                SELECT EXTRACT(EPOCH FROM (NOW() - MIN(created_at)))::bigint
                FROM claimable
              ) AS oldest_claimable_queued_age_secs
            "#,
        )
        .fetch_one(&self.pool)
        .await?;

        let kind_rows = sqlx::query(
            r#"
            SELECT kind, COUNT(*)::bigint AS c
            FROM app_generation_job
            WHERE status = 'queued'
            GROUP BY kind
            ORDER BY c DESC, kind ASC
            LIMIT 15
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut by_kind: Map<String, Value> = Map::new();
        for r in kind_rows {
            let kind: String = r.get("kind");
            let c: i64 = r.get("c");
            by_kind.insert(kind, json!(c));
        }

        Ok(QueueStats {
            pending: row.get("pending"),
            pending_claimable: row.get("pending_claimable"),
            running: row.get("running"),
            dead: row.get("dead"),
            failed_last_24h: row.get("failed_last_24h"),
            oldest_claimable_queued_age_secs: row.get("oldest_claimable_queued_age_secs"),
            pending_by_kind_json: Value::Object(by_kind),
        })
    }
}
