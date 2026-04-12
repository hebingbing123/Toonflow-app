//! 核心 HTTP 处理器。
//!
//! 由 [`super::router::build_router`] 挂载，提供健康检查、版本信息、
//! 就绪状态和用户信息服务。

use crate::auth::require_claims;
use crate::error::ApiError;
use crate::state::{AppState, MemoryConfig};

use axum::extract::State;
use axum::http::HeaderMap;
use axum::Json;
use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

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

#[derive(FromRow)]
struct UserProfileRow {
    plan_tier: String,
    billing_currency: Option<String>,
    billing_provider: Option<String>,
    subscription_status: Option<String>,
    subscription_current_period_end_at: Option<DateTime<Utc>>,
    daily_job_quota: Option<i64>,
    memory_config: Option<sqlx::types::Json<MemoryConfig>>,
}

#[utoipa::path(
    get,
    path = "/health",
    operation_id = "healthRoot",
    tag = "system",
    summary = "Liveness (unversioned)",
    responses((status = 200, description = "OK", body = HealthResponse))
)]
pub(crate) async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "toonflow-server",
    })
}

#[utoipa::path(
    get,
    path = "/api/v1/ping",
    operation_id = "pingV1",
    tag = "system",
    summary = "Minimal connectivity probe (Electron `/api/test/test` parity)",
    description = "Public, no auth, no database. Replaces Electron-era **`GET /api/test/test`** which returned plain text **`ok`**; this route returns JSON **`{\"ok\":true}`** for versioned API clients.",
    responses((status = 200, description = "OK", body = PingResponse))
)]
pub(crate) async fn ping() -> Json<PingResponse> {
    Json(PingResponse { ok: true })
}

#[utoipa::path(
    get,
    path = "/api/v1/version",
    operation_id = "versionV1",
    tag = "system",
    summary = "Server semantic version (from Cargo package)",
    description = "Public, no auth. Aligns with Electron-era **`/api/other/getVersion`** use cases for client compatibility checks.\nWhen the server binary is compiled with environment **`TOONFLOW_GIT_SHA`** set, the JSON may include **`git_sha`** (opaque string, often a Git commit id).",
    responses((status = 200, description = "OK", body = VersionResponse))
)]
pub(crate) async fn version() -> Json<VersionResponse> {
    Json(VersionResponse {
        service: "toonflow-server",
        version: env!("CARGO_PKG_VERSION"),
        git_sha: option_env!("TOONFLOW_GIT_SHA"),
    })
}

#[utoipa::path(
    get,
    path = "/api/v1/ready",
    operation_id = "readyV1",
    tag = "system",
    summary = "Readiness (optional database ping)",
    description = "If `DATABASE_URL` is set, runs `SELECT 1`. Otherwise returns `database: not_configured` (HTTP 200).",
    responses(
        (status = 200, description = "OK", body = ReadyResponse),
        (status = 503, description = "Database unreachable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn ready(State(state): State<AppState>) -> Result<Json<ReadyResponse>, ApiError> {
    match &state.pool {
        None => Ok(Json(ReadyResponse {
            status: "ok",
            database: "not_configured",
        })),
        Some(pool) => {
            sqlx::query_scalar::<_, i32>("SELECT 1")
                .fetch_one(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            Ok(Json(ReadyResponse {
                status: "ok",
                database: "connected",
            }))
        }
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/me",
    operation_id = "meV1",
    tag = "session",
    summary = "Current user from JWT plus SaaS profile when database is configured",
    description = "Always returns JWT `sub` (and `email` when present in claims). When **`DATABASE_URL`** is set, loads **`plan_tier`** / billing fields from **`app_user_profile`** (defaults to **`plan_tier: free`** when no row).\nIncludes `subscription_status` and `subscription_current_period_end_at` when present in profile.\nAlso returns **`daily_job_quota`** (effective cap; `null` = unlimited) and **`jobs_today`** (UTC-day count) when the database is connected — clients can use these to render quota progress without a separate call.",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "OK", body = MeResponse),
        (status = 401, description = "Missing or invalid Bearer token", body = crate::error::ErrorBody),
        (status = 503, description = "`SUPABASE_JWT_SECRET` not configured, or database error when loading profile", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn me(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MeResponse>, ApiError> {
    let claims = require_claims(&state, &headers)?;
    let sub = Uuid::parse_str(claims.sub.trim()).map_err(|_| ApiError::BadToken)?;

    let (
        plan_tier,
        billing_currency,
        billing_provider,
        subscription_status,
        subscription_current_period_end_at,
        per_user_quota,
        jobs_today,
        memory_cfg,
    ) = if let Some(pool) = state.pool.as_ref() {
        let row = sqlx::query_as::<_, UserProfileRow>(
            r#"
            SELECT
              plan_tier,
              billing_currency,
              billing_provider,
              subscription_status,
              subscription_current_period_end_at,
              daily_job_quota,
              memory_config
            FROM app_user_profile
            WHERE user_id = $1
            "#,
        )
        .bind(sub)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let (
            tier,
            currency,
            provider,
            subscription_status,
            subscription_current_period_end_at,
            per_user_quota,
            mem_cfg,
        ) = match row {
            Some(r) => (
                r.plan_tier,
                r.billing_currency,
                r.billing_provider,
                r.subscription_status,
                r.subscription_current_period_end_at,
                r.daily_job_quota,
                r.memory_config.map(|j| j.0),
            ),
            None => ("free".to_string(), None, None, None, None, None, None),
        };

        let today: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE owner_user_id = $1
              AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
            "#,
        )
        .bind(sub)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        (
            tier,
            currency,
            provider,
            subscription_status,
            subscription_current_period_end_at,
            per_user_quota,
            Some(today),
            mem_cfg,
        )
    } else {
        ("free".to_string(), None, None, None, None, None, None, None)
    };

    // Resolve effective quota using same logic as quota::effective_daily_job_quota
    // but inline (avoids a second DB round-trip).
    let daily_job_quota = if per_user_quota.is_some() {
        per_user_quota
    } else {
        let free_limit = std::env::var("QUOTA_FREE_DAILY_JOBS")
            .ok()
            .and_then(|s| s.trim().parse::<i64>().ok())
            .filter(|&n| n > 0)
            .unwrap_or(20);
        match plan_tier.as_str() {
            "enterprise" => None,
            "free" => Some(free_limit),
            "creator" => Some(free_limit * 40),
            "pro" => Some(free_limit * 125),
            "studio" => Some(free_limit * 400),
            _ => Some(free_limit),
        }
    };

    // Resolve memory_config (use DB value or fall back to server defaults).
    let memory_config = if memory_cfg.is_some() {
        memory_cfg
    } else if state.pool.is_none() {
        Some(state.memory_config.read().await.clone())
    } else {
        None // DB connected but user has no custom config; don't leak server defaults.
    };

    Ok(Json(MeResponse {
        sub,
        email: claims.email,
        plan_tier,
        billing_currency,
        billing_provider,
        subscription_status,
        subscription_current_period_end_at,
        daily_job_quota,
        jobs_today,
        memory_config,
    }))
}
