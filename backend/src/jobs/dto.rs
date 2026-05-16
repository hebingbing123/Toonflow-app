use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
pub struct JobRow {
    #[serde(rename = "numeric_task_id")]
    #[sqlx(rename = "numeric_task_id")]
    pub numeric_task_id: i64,
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub kind: String,
    pub status: String,
    pub payload: Value,
    pub result: Option<Value>,
    pub error_message: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error_details: Option<Value>,
    pub idempotency_key: Option<String>,
    /// Worker label (`WORKER_ID` env) when `running`; set on claim.
    pub claimed_by: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    /// Stable sub‑type for UX / analytics (**also** in **`payload.job_sub_kind`**).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    #[sqlx(skip)]
    pub job_sub_kind: Option<String>,
    /// Coarse production stage (**also** in **`payload.production_phase`**).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    #[sqlx(skip)]
    pub production_phase: Option<String>,
}

#[derive(Debug, FromRow)]
pub(crate) struct JobFileSource {
    pub(crate) result: sqlx::types::Json<Value>,
}

#[derive(Debug, Deserialize, Default)]
pub(super) struct ListJobsQuery {
    #[serde(default)]
    pub(super) kind: Option<String>,
    #[serde(default)]
    pub(super) status: Option<String>,
    #[serde(default)]
    pub(super) project_id: Option<i32>,
    #[serde(default)]
    pub(super) limit: Option<i64>,
    #[serde(default)]
    pub(super) offset: Option<i64>,
}

/// Task-center style pagination (1-based `page`, replaces Electron-era `POST /api/v1/tasks/get-task-api`).
#[derive(Debug, Deserialize, Default)]
pub(super) struct ListJobsPageQuery {
    #[serde(default)]
    pub(super) page: Option<i32>,
    #[serde(default)]
    pub(super) limit: Option<i32>,
    #[serde(default)]
    pub(super) state: Option<String>,
    #[serde(default)]
    pub(super) task_class: Option<String>,
    #[serde(default)]
    pub(super) project_id: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct ListJobsPageResponse {
    pub data: Vec<JobRow>,
    pub total: i64,
}

#[derive(Debug, Deserialize, Default)]
pub(super) struct JobSummaryQuery {
    #[serde(default)]
    pub(super) project_id: Option<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CreateJobBody {
    pub kind: String,
    #[serde(default)]
    pub payload: Value,
}

#[derive(Debug, FromRow, Serialize)]
pub(super) struct JobKindSummaryRow {
    pub(super) kind: String,
    pub(super) job_count: i64,
}

#[derive(Debug, FromRow, Serialize)]
pub(super) struct JobStatusSummaryRow {
    pub(super) status: String,
    pub(super) job_count: i64,
}
