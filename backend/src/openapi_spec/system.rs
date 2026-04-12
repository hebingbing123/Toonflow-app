//! OpenAPI-only path entries (same Axum handler wired to multiple routes).

/// Same JSON as [`crate::app::handlers::health`]; documents `GET /api/v1/health`.
#[utoipa::path(
    get,
    path = "/api/v1/health",
    operation_id = "healthV1",
    tag = "system",
    summary = "Liveness (versioned)",
    responses((status = 200, description = "OK", body = crate::app::handlers::HealthResponse))
)]
#[allow(dead_code)]
pub(crate) fn health_v1_openapi() {}
