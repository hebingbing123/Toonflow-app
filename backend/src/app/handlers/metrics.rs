//! Metrics and SLI endpoints for observability.

use std::collections::HashMap;

use axum::{extract::State, Json};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};

use crate::error::ApiError;
use crate::http_kit::metrics::{
    registry::EndpointMetrics, sli::SliSnapshot, SliDefinition, SLI_DEFINITIONS,
};
use crate::state::AppState;

/// Query parameters for metrics endpoint.
#[derive(Debug, Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MetricsQuery {
    /// Time window in minutes (default: 60)
    #[serde(default = "default_window_minutes")]
    pub window_minutes: u64,
}

fn default_window_minutes() -> u64 {
    60
}

/// Metrics response.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MetricsResponse {
    /// Aggregated metrics by endpoint
    pub endpoints: HashMap<String, EndpointMetrics>,
    /// Time window in minutes
    pub window_minutes: u64,
}

/// SLI status response.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SliStatusResponse {
    /// SLI snapshots for all critical paths
    pub slis: Vec<SliSnapshot>,
    /// Overall system health (all SLIs healthy)
    pub healthy: bool,
    /// Time window in minutes
    pub window_minutes: u64,
}

/// Get aggregated metrics for all endpoints.
#[utoipa::path(
    get,
    path = "/api/v1/metrics",
    operation_id = "getMetricsV1",
    tag = "observability",
    params(MetricsQuery),
    responses(
        (status = 200, description = "Aggregated metrics", body = MetricsResponse),
    )
)]
pub async fn get_metrics(
    State(state): State<AppState>,
    axum::extract::Query(query): axum::extract::Query<MetricsQuery>,
) -> Result<Json<MetricsResponse>, ApiError> {
    let endpoints = state
        .metrics_registry
        .get_aggregated_metrics(query.window_minutes)
        .await;

    Ok(Json(MetricsResponse {
        endpoints,
        window_minutes: query.window_minutes,
    }))
}

/// Get SLI status for all critical paths.
#[utoipa::path(
    get,
    path = "/api/v1/metrics/sli",
    operation_id = "getSliStatusV1",
    tag = "observability",
    params(MetricsQuery),
    responses(
        (status = 200, description = "SLI status", body = SliStatusResponse),
    )
)]
pub async fn get_sli_status(
    State(state): State<AppState>,
    axum::extract::Query(query): axum::extract::Query<MetricsQuery>,
) -> Result<Json<SliStatusResponse>, ApiError> {
    let endpoint_metrics = state
        .metrics_registry
        .get_aggregated_metrics(query.window_minutes)
        .await;

    let mut slis = Vec::new();
    let mut all_healthy = true;

    for definition in SLI_DEFINITIONS.iter() {
        let snapshot = compute_sli_snapshot(definition, &endpoint_metrics);
        if !snapshot.healthy {
            all_healthy = false;
        }
        slis.push(snapshot);
    }

    Ok(Json(SliStatusResponse {
        slis,
        healthy: all_healthy,
        window_minutes: query.window_minutes,
    }))
}

/// Get SLI definitions.
#[utoipa::path(
    get,
    path = "/api/v1/metrics/sli/definitions",
    operation_id = "getSliDefinitionsV1",
    tag = "observability",
    responses(
        (status = 200, description = "SLI definitions", body = Vec<SliDefinition>),
    )
)]
pub async fn get_sli_definitions() -> Json<Vec<SliDefinition>> {
    Json(SLI_DEFINITIONS.to_vec())
}

/// Compute SLI snapshot from endpoint metrics.
fn compute_sli_snapshot(
    definition: &SliDefinition,
    endpoint_metrics: &HashMap<String, EndpointMetrics>,
) -> SliSnapshot {
    // Aggregate metrics for all endpoints in this SLI
    let mut total_requests = 0u64;
    let mut total_success = 0u64;
    let mut total_available = 0u64;
    let mut max_p95_latency = 0u64;

    for (path, metrics) in endpoint_metrics {
        if definition.matches_endpoint(path) {
            total_requests += metrics.total_requests;
            total_success += metrics.success_count;
            total_available += metrics.total_requests - metrics.server_error_count;
            max_p95_latency = max_p95_latency.max(metrics.p95_latency_ms);
        }
    }

    let current_success_rate = if total_requests > 0 {
        total_success as f64 / total_requests as f64
    } else {
        1.0 // No requests = 100% success rate
    };

    let current_availability = if total_requests > 0 {
        total_available as f64 / total_requests as f64
    } else {
        1.0 // No requests = 100% availability
    };

    let latency_meets_target = max_p95_latency <= definition.target_p95_latency_ms;
    let success_rate_meets_target = current_success_rate >= definition.target_success_rate;
    let availability_meets_target = current_availability >= definition.target_availability;

    let healthy = latency_meets_target && success_rate_meets_target && availability_meets_target;

    SliSnapshot {
        path: definition.path,
        definition: definition.clone(),
        current_p95_latency_ms: max_p95_latency,
        current_success_rate,
        current_availability,
        latency_meets_target,
        success_rate_meets_target,
        availability_meets_target,
        healthy,
        total_requests,
    }
}
