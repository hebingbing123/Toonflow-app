//! 健康检查、ping、版本与就绪探针。

use axum::extract::State;
use axum::Json;

use crate::error::ApiError;
use crate::state::AppState;

use super::types::{
    HealthResponse, PingResponse, ReadyHarnessIsolateMetrics, ReadyResponse, VersionResponse,
};
use crate::harness::isolate;

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
    description = "If `DATABASE_URL` is set, runs `SELECT 1`. Otherwise returns `database: not_configured` (HTTP 200). Includes **`harness_isolate`** counters (see `isolate::metrics_snapshot`) for observability.",
    responses(
        (status = 200, description = "OK", body = ReadyResponse),
        (status = 503, description = "Database unreachable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn ready(State(state): State<AppState>) -> Result<Json<ReadyResponse>, ApiError> {
    let snap = isolate::metrics_snapshot();
    let harness_isolate = ReadyHarnessIsolateMetrics {
        max_slots: snap.max_slots,
        queue_depth_waiting: snap.queue_depth_waiting,
        available_permits_snapshot: snap.available_permits_snapshot,
        total_invocations: snap.total_invocations,
        total_semaphore_wait_ms: snap.total_semaphore_wait_ms,
        total_child_spawns: snap.total_child_spawns,
        total_process_reuse_hits: snap.total_process_reuse_hits,
        total_pool_evictions: snap.total_pool_evictions,
    };
    match &state.pool {
        None => Ok(Json(ReadyResponse {
            status: "ok",
            database: "not_configured",
            harness_isolate,
        })),
        Some(pool) => {
            sqlx::query_scalar::<_, i32>("SELECT 1")
                .fetch_one(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            Ok(Json(ReadyResponse {
                status: "ok",
                database: "connected",
                harness_isolate,
            }))
        }
    }
}
