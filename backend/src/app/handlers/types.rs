//! 核心系统与会话 JSON 响应类型（OpenAPI components）。

use chrono::{DateTime, Utc};
use serde::Serialize;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::state::MemoryConfig;

#[derive(Serialize, ToSchema)]
pub(crate) struct HealthResponse {
    pub status: &'static str,
    pub service: &'static str,
}

/// Minimal JSON probe; replaces Electron-era **`GET /api/test/test`** (`"ok"` plain text).
#[derive(Serialize, ToSchema)]
pub(crate) struct PingResponse {
    pub ok: bool,
}

#[derive(Serialize, ToSchema)]
pub(crate) struct VersionResponse {
    pub service: &'static str,
    pub version: &'static str,
    /// Present when the binary was built with env **`TOONFLOW_GIT_SHA`** set (compile-time `option_env!`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub git_sha: Option<&'static str>,
}

#[derive(Serialize, ToSchema)]
pub(crate) struct ReadyResponse {
    pub status: &'static str,
    pub database: &'static str,
}

#[derive(Serialize, ToSchema)]
pub(crate) struct MeResponse {
    pub sub: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
    /// From `app_user_profile` when connected; defaults to `free` when no row.
    pub plan_tier: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub billing_currency: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub billing_provider: Option<String>,
    /// Current subscription status derived from billing webhook profile updates.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub subscription_status: Option<String>,
    /// Period end timestamp of current paid subscription cycle.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub subscription_current_period_end_at: Option<DateTime<Utc>>,
    /// Effective daily job quota for this user (null = unlimited, e.g. enterprise).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub daily_job_quota: Option<i64>,
    /// Number of generation jobs created today (UTC natural day). Present when DB is connected.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jobs_today: Option<i64>,
    /// User memory/RAG configuration from `app_user_profile.memory_config` (or server defaults).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_config: Option<MemoryConfig>,
}
