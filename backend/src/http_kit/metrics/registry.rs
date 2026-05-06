//! Metrics registry for storing and aggregating request metrics.

use std::collections::HashMap;
use std::sync::Arc;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;
use utoipa::ToSchema;

/// Individual request metrics captured by middleware.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequestMetrics {
    /// Request ID for correlation
    pub request_id: String,
    /// HTTP method
    pub method: String,
    /// Request path (normalized, e.g., /api/v1/projects/{id}/production-overview)
    pub path: String,
    /// HTTP status code
    pub status: u16,
    /// Request duration in milliseconds
    pub duration_ms: u64,
    /// Timestamp when request completed
    pub timestamp: DateTime<Utc>,
    /// Error code if request failed (from ErrorBody)
    pub error_code: Option<String>,
    /// User ID if authenticated
    pub user_id: Option<String>,
}

/// Aggregated metrics for a specific endpoint.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct EndpointMetrics {
    /// Endpoint path pattern
    pub path: String,
    /// Total request count
    pub total_requests: u64,
    /// Successful requests (2xx status)
    pub success_count: u64,
    /// Client error requests (4xx status)
    pub client_error_count: u64,
    /// Server error requests (5xx status)
    pub server_error_count: u64,
    /// Success rate (0.0 to 1.0)
    pub success_rate: f64,
    /// p50 latency in milliseconds
    pub p50_latency_ms: u64,
    /// p95 latency in milliseconds
    pub p95_latency_ms: u64,
    /// p99 latency in milliseconds
    pub p99_latency_ms: u64,
    /// Average latency in milliseconds
    pub avg_latency_ms: u64,
    /// Error breakdown by error code
    pub error_breakdown: HashMap<String, u64>,
    /// Time window for these metrics
    pub window_start: DateTime<Utc>,
    pub window_end: DateTime<Utc>,
}

/// Global metrics registry.
pub struct MetricsRegistry {
    /// Recent request metrics (ring buffer, last N requests)
    recent_requests: Arc<RwLock<Vec<RequestMetrics>>>,
    /// Maximum number of recent requests to keep
    max_recent: usize,
}

impl MetricsRegistry {
    /// Create a new metrics registry.
    pub fn new(max_recent: usize) -> Self {
        Self {
            recent_requests: Arc::new(RwLock::new(Vec::with_capacity(max_recent))),
            max_recent,
        }
    }

    /// Record a request metric.
    pub async fn record(&self, metric: RequestMetrics) {
        let mut recent = self.recent_requests.write().await;
        recent.push(metric);

        // Keep only the most recent N requests
        if recent.len() > self.max_recent {
            let drain_count = recent.len() - self.max_recent;
            recent.drain(0..drain_count);
        }
    }

    /// Get aggregated metrics for all endpoints in the time window.
    pub async fn get_aggregated_metrics(
        &self,
        window_minutes: u64,
    ) -> HashMap<String, EndpointMetrics> {
        let recent = self.recent_requests.read().await;
        let now = Utc::now();
        let window_start = now - chrono::Duration::minutes(window_minutes as i64);

        // Filter to time window
        let windowed: Vec<_> = recent
            .iter()
            .filter(|m| m.timestamp >= window_start)
            .collect();

        // Group by path
        let mut by_path: HashMap<String, Vec<&RequestMetrics>> = HashMap::new();
        for metric in windowed {
            by_path.entry(metric.path.clone()).or_default().push(metric);
        }

        // Aggregate per endpoint
        by_path
            .into_iter()
            .map(|(path, metrics)| {
                let endpoint_metrics =
                    Self::aggregate_endpoint_metrics(&path, &metrics, window_start, now);
                (path, endpoint_metrics)
            })
            .collect()
    }

    /// Aggregate metrics for a single endpoint.
    fn aggregate_endpoint_metrics(
        path: &str,
        metrics: &[&RequestMetrics],
        window_start: DateTime<Utc>,
        window_end: DateTime<Utc>,
    ) -> EndpointMetrics {
        let total_requests = metrics.len() as u64;
        let success_count = metrics
            .iter()
            .filter(|m| m.status >= 200 && m.status < 300)
            .count() as u64;
        let client_error_count = metrics
            .iter()
            .filter(|m| m.status >= 400 && m.status < 500)
            .count() as u64;
        let server_error_count = metrics.iter().filter(|m| m.status >= 500).count() as u64;

        let success_rate = if total_requests > 0 {
            success_count as f64 / total_requests as f64
        } else {
            0.0
        };

        // Calculate latency percentiles
        let mut durations: Vec<u64> = metrics.iter().map(|m| m.duration_ms).collect();
        durations.sort_unstable();

        let p50_latency_ms = Self::percentile(&durations, 0.50);
        let p95_latency_ms = Self::percentile(&durations, 0.95);
        let p99_latency_ms = Self::percentile(&durations, 0.99);
        let avg_latency_ms = if !durations.is_empty() {
            durations.iter().sum::<u64>() / durations.len() as u64
        } else {
            0
        };

        // Error breakdown
        let mut error_breakdown: HashMap<String, u64> = HashMap::new();
        for metric in metrics {
            if let Some(code) = &metric.error_code {
                *error_breakdown.entry(code.clone()).or_insert(0) += 1;
            }
        }

        EndpointMetrics {
            path: path.to_string(),
            total_requests,
            success_count,
            client_error_count,
            server_error_count,
            success_rate,
            p50_latency_ms,
            p95_latency_ms,
            p99_latency_ms,
            avg_latency_ms,
            error_breakdown,
            window_start,
            window_end,
        }
    }

    /// Calculate percentile from sorted durations.
    fn percentile(sorted_durations: &[u64], percentile: f64) -> u64 {
        if sorted_durations.is_empty() {
            return 0;
        }
        let index = ((sorted_durations.len() as f64 - 1.0) * percentile) as usize;
        sorted_durations[index]
    }

    /// Get recent requests for debugging.
    pub async fn get_recent_requests(&self, limit: usize) -> Vec<RequestMetrics> {
        let recent = self.recent_requests.read().await;
        let start = recent.len().saturating_sub(limit);
        recent[start..].to_vec()
    }

    /// Clear all metrics (for testing).
    #[cfg(test)]
    pub async fn clear(&self) {
        let mut recent = self.recent_requests.write().await;
        recent.clear();
    }
}

impl Default for MetricsRegistry {
    fn default() -> Self {
        // Keep last 10,000 requests in memory (~1-2 MB)
        Self::new(10_000)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_record_and_aggregate() {
        let registry = MetricsRegistry::new(100);

        // Record some metrics
        for i in 0..10 {
            registry
                .record(RequestMetrics {
                    request_id: format!("req-{}", i),
                    method: "GET".to_string(),
                    path: "/api/v1/test".to_string(),
                    status: if i < 8 { 200 } else { 500 },
                    duration_ms: 100 + i * 10,
                    timestamp: Utc::now(),
                    error_code: if i >= 8 {
                        Some("internal_error".to_string())
                    } else {
                        None
                    },
                    user_id: Some("user-123".to_string()),
                })
                .await;
        }

        let aggregated = registry.get_aggregated_metrics(60).await;
        let metrics = aggregated.get("/api/v1/test").unwrap();

        assert_eq!(metrics.total_requests, 10);
        assert_eq!(metrics.success_count, 8);
        assert_eq!(metrics.server_error_count, 2);
        assert_eq!(metrics.success_rate, 0.8);
        assert!(metrics.p50_latency_ms > 0);
        assert_eq!(metrics.error_breakdown.get("internal_error"), Some(&2));
    }

    #[test]
    fn test_percentile_calculation() {
        let durations = vec![10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
        // For 10 elements (indices 0-9):
        // p50 = (10-1) * 0.50 = 4.5 → index 4 → value 50
        // p95 = (10-1) * 0.95 = 8.55 → index 8 → value 90
        // p99 = (10-1) * 0.99 = 8.91 → index 8 → value 90
        assert_eq!(MetricsRegistry::percentile(&durations, 0.50), 50);
        assert_eq!(MetricsRegistry::percentile(&durations, 0.95), 90);
        assert_eq!(MetricsRegistry::percentile(&durations, 0.99), 90);
    }

    #[test]
    fn test_percentile_empty() {
        let durations: Vec<u64> = vec![];
        assert_eq!(MetricsRegistry::percentile(&durations, 0.50), 0);
    }
}
