//! Core HTTP handlers mounted from [`super::router::build_router`] (health, version, ready, me).

use crate::auth::require_claims;
use crate::error::ApiError;
use crate::state::AppState;

use axum::extract::State;
use axum::http::HeaderMap;
use axum::Json;
use serde::Serialize;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Serialize)]
pub(super) struct HealthResponse {
    pub status: &'static str,
    pub service: &'static str,
}

/// Minimal JSON probe; replaces legacy **`GET /api/test/test`** (`"ok"` plain text).
#[derive(Serialize)]
pub(super) struct PingResponse {
    pub ok: bool,
}

#[derive(Serialize)]
pub(super) struct VersionResponse {
    pub service: &'static str,
    pub version: &'static str,
    /// Present when the binary was built with env **`TOONFLOW_GIT_SHA`** set (compile-time `option_env!`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub git_sha: Option<&'static str>,
}

#[derive(Serialize)]
pub(super) struct ReadyResponse {
    pub status: &'static str,
    pub database: &'static str,
}

#[derive(Serialize)]
pub(super) struct MeResponse {
    pub sub: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
    /// From `app_user_profile` when connected; defaults to `free` when no row.
    pub plan_tier: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub billing_currency: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub billing_provider: Option<String>,
    /// Effective daily job quota for this user (null = unlimited, e.g. enterprise).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub daily_job_quota: Option<i64>,
    /// Number of generation jobs created today (UTC natural day). Present when DB is connected.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jobs_today: Option<i64>,
}

#[derive(FromRow)]
struct UserProfileRow {
    plan_tier: String,
    billing_currency: Option<String>,
    billing_provider: Option<String>,
    daily_job_quota: Option<i64>,
}

pub(super) async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "toonflow-server",
    })
}

pub(super) async fn ping() -> Json<PingResponse> {
    Json(PingResponse { ok: true })
}

pub(super) async fn version() -> Json<VersionResponse> {
    Json(VersionResponse {
        service: "toonflow-server",
        version: env!("CARGO_PKG_VERSION"),
        git_sha: option_env!("TOONFLOW_GIT_SHA"),
    })
}

pub(super) async fn ready(State(state): State<AppState>) -> Result<Json<ReadyResponse>, ApiError> {
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

pub(super) async fn me(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MeResponse>, ApiError> {
    let claims = require_claims(&state, &headers)?;
    let sub = Uuid::parse_str(claims.sub.trim()).map_err(|_| ApiError::BadToken)?;

    let (plan_tier, billing_currency, billing_provider, per_user_quota, jobs_today) =
        if let Some(pool) = state.pool.as_ref() {
            let row = sqlx::query_as::<_, UserProfileRow>(
                r#"
                SELECT plan_tier, billing_currency, billing_provider, daily_job_quota
                FROM app_user_profile
                WHERE user_id = $1
                "#,
            )
            .bind(sub)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            let (tier, currency, provider, per_user_quota) = match row {
                Some(r) => (
                    r.plan_tier,
                    r.billing_currency,
                    r.billing_provider,
                    r.daily_job_quota,
                ),
                None => ("free".to_string(), None, None, None),
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

            (tier, currency, provider, per_user_quota, Some(today))
        } else {
            ("free".to_string(), None, None, None, None)
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

    Ok(Json(MeResponse {
        sub,
        email: claims.email,
        plan_tier,
        billing_currency,
        billing_provider,
        daily_job_quota,
        jobs_today,
    }))
}
