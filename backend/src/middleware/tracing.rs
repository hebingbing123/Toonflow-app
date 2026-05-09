//! API 请求追踪中间件
//!
//! 为所有 API 端点添加分布式追踪支持，记录请求详情和性能指标。

use axum::{extract::Request, middleware::Next, response::Response};
use std::time::Instant;
use tracing::{info_span, Instrument};

/// API 请求追踪中间件
///
/// 为每个请求创建一个 span，记录：
/// - HTTP 方法和路径
/// - 请求 ID（如果存在）
/// - 响应状态码
/// - 请求处理时长
pub async fn trace_request(req: Request, next: Next) -> Response {
    let start = Instant::now();
    let method = req.method().clone();
    let uri = req.uri().clone();
    let path = uri.path().to_string();

    // 提取请求 ID（如果存在）
    let request_id = req
        .headers()
        .get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("unknown")
        .to_string();

    // 创建 span 并处理请求
    let span = info_span!(
        "http_request",
        method = %method,
        path = %path,
        request_id = %request_id,
    );

    async move {
        let response = next.run(req).await;
        let duration = start.elapsed();
        let status = response.status();

        // 记录请求完成
        tracing::info!(
            target: "toonflow.api.request",
            method = %method,
            path = %path,
            status = %status.as_u16(),
            duration_ms = %duration.as_millis(),
            request_id = %request_id,
            "Request completed"
        );

        // 记录到 metrics 模块
        crate::metrics::record_api_request(&path, method.as_str(), status.as_u16(), duration);

        response
    }
    .instrument(span)
    .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::Body,
        http::{Request, StatusCode},
        middleware,
        response::IntoResponse,
        routing::get,
        Router,
    };
    use tower::ServiceExt;

    async fn test_handler() -> impl IntoResponse {
        (StatusCode::OK, "test response")
    }

    #[tokio::test]
    async fn test_trace_request_middleware() {
        let app = Router::new()
            .route("/test", get(test_handler))
            .layer(middleware::from_fn(trace_request));

        let request = Request::builder()
            .uri("/test")
            .header("x-request-id", "test-123")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);
    }
}
