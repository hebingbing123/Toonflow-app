//! Metrics collection middleware for tracking request latency and success rates.

use std::time::Instant;

use axum::{
    extract::{Request, State},
    middleware::Next,
    response::Response,
};

use crate::state::AppState;

use super::registry::RequestMetrics;

/// Middleware function to collect request metrics.
pub async fn collect_metrics(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Response {
    let start = Instant::now();
    let method = request.method().to_string();
    let path = normalize_path(request.uri().path());

    // Extract request ID if present
    let request_id = request
        .headers()
        .get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("unknown")
        .to_string();

    // Extract user ID from JWT if present (simplified - could parse JWT)
    let user_id = extract_user_id_from_auth(&request);

    let response = next.run(request).await;
    let duration = start.elapsed();
    let status = response.status();

    // Extract error code from response body if it's an error
    let error_code = if status.is_client_error() || status.is_server_error() {
        extract_error_code_from_response(&response).await
    } else {
        None
    };

    // Record metrics
    let metric = RequestMetrics {
        request_id,
        method,
        path,
        status: status.as_u16(),
        duration_ms: duration.as_millis() as u64,
        timestamp: chrono::Utc::now(),
        error_code,
        user_id,
    };

    state.metrics_registry.record(metric).await;

    response
}

/// Normalize path by replacing IDs with placeholders.
fn normalize_path(path: &str) -> String {
    let mut normalized = path.to_string();

    // Replace UUIDs with {id}
    let uuid_pattern =
        regex::Regex::new(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}").unwrap();
    normalized = uuid_pattern.replace_all(&normalized, "{id}").to_string();

    // Replace numeric IDs with {id}
    let numeric_pattern = regex::Regex::new(r"/\d+(/|$)").unwrap();
    normalized = numeric_pattern
        .replace_all(&normalized, "/{id}$1")
        .to_string();

    normalized
}

/// Extract user ID from Authorization header (simplified).
fn extract_user_id_from_auth(request: &Request) -> Option<String> {
    let auth_header = request.headers().get("authorization")?;
    let auth_str = auth_header.to_str().ok()?;

    // Extract from "Bearer <token>" - in production, would decode JWT
    if auth_str.starts_with("Bearer ") {
        // For now, just return a placeholder
        // In production, decode JWT and extract user_id claim
        Some("authenticated".to_string())
    } else {
        None
    }
}

/// Extract error code from response body (if JSON error response).
async fn extract_error_code_from_response(_response: &Response) -> Option<String> {
    // This is a simplified version - in production, would need to clone body
    // For now, return None to avoid consuming the body
    // A proper implementation would use a custom body type that can be cloned
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_path_uuid() {
        let path = "/api/v1/projects/550e8400-e29b-41d4-a716-446655440000/publish/drafts";
        let normalized = normalize_path(path);
        assert_eq!(normalized, "/api/v1/projects/{id}/publish/drafts");
    }

    #[test]
    fn test_normalize_path_numeric() {
        let path = "/api/v1/projects/123/publish/drafts/456";
        let normalized = normalize_path(path);
        assert_eq!(normalized, "/api/v1/projects/{id}/publish/drafts/{id}");
    }

    #[test]
    fn test_normalize_path_no_ids() {
        let path = "/api/v1/health";
        let normalized = normalize_path(path);
        assert_eq!(normalized, "/api/v1/health");
    }
}
