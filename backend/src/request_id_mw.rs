//! `X-Request-Id` propagation and JSON [`crate::error::ErrorBody`] `request_id` injection.

use axum::{body::Body, extract::Request, http::header, middleware::Next, response::Response};
use serde_json::{json, Value};

const MAX_ERROR_JSON: usize = 65_536;

/// Runs **inside** [`tower_http::request_id::SetRequestId`] / [`tower_http::request_id::PropagateRequestId`]:
/// copies `x-request-id` from the request into JSON error bodies that match `ErrorBody` (`code` + `message`, no `request_id` yet).
pub async fn inject_request_id_into_json_errors(request: Request, next: Next) -> Response {
    let rid = request
        .headers()
        .get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    let response = next.run(request).await;

    let Some(rid) = rid else {
        return response;
    };

    let status = response.status();
    if !status.is_client_error() && !status.is_server_error() {
        return response;
    }

    let (parts, body) = response.into_parts();
    let ct_json = parts
        .headers
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .map(|c| c.starts_with("application/json"))
        .unwrap_or(false);
    if !ct_json {
        return Response::from_parts(parts, body);
    }

    match axum::body::to_bytes(body, MAX_ERROR_JSON).await {
        Ok(bytes) => {
            let Ok(mut v) = serde_json::from_slice::<Value>(&bytes) else {
                return Response::from_parts(parts, Body::from(bytes));
            };
            if let Some(obj) = v.as_object_mut() {
                if obj.get("code").is_some()
                    && obj.get("message").is_some()
                    && obj.get("request_id").is_none()
                {
                    obj.insert("request_id".into(), json!(rid));
                }
            }
            let out = serde_json::to_vec(&v).unwrap_or_else(|_| bytes.to_vec());
            Response::from_parts(parts, Body::from(out))
        }
        Err(_) => Response::from_parts(parts, Body::empty()),
    }
}

#[cfg(test)]
mod tests {
    use std::net::SocketAddr;

    use super::*;
    use axum::extract::ConnectInfo;
    use axum::http::Request;
    use tower::util::ServiceExt;

    use crate::app::build_router;
    use crate::notify_hub::WsNotifyHub;
    use std::sync::Arc;

    use tokio::sync::RwLock;

    use crate::state::{AppState, MemoryConfig};

    fn test_addr() -> SocketAddr {
        SocketAddr::from(([127, 0, 0, 1], 9_001))
    }

    fn test_state() -> AppState {
        AppState {
            pool: None,
            jwt_secret: Some(b"not-empty".to_vec()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        }
    }

    #[tokio::test]
    async fn me_without_auth_json_matches_x_request_id_header() {
        let app = build_router(test_state());
        let res = app
            .oneshot(
                Request::builder()
                    .uri("/api/v1/me")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(res.status(), axum::http::StatusCode::UNAUTHORIZED);
        let hdr = res
            .headers()
            .get("x-request-id")
            .expect("x-request-id header")
            .to_str()
            .unwrap()
            .to_string();
        let body = axum::body::to_bytes(res.into_body(), MAX_ERROR_JSON)
            .await
            .unwrap();
        let v: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(v["code"], "unauthorized");
        assert_eq!(v["request_id"].as_str().unwrap(), hdr);
    }

    #[tokio::test]
    async fn client_supplied_x_request_id_is_preserved() {
        let app = build_router(test_state());
        let res = app
            .oneshot(
                Request::builder()
                    .uri("/api/v1/me")
                    .header("x-request-id", "client-fixed-id")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(
            res.headers().get("x-request-id").unwrap().to_str().unwrap(),
            "client-fixed-id"
        );
        let body = axum::body::to_bytes(res.into_body(), MAX_ERROR_JSON)
            .await
            .unwrap();
        let v: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(v["request_id"].as_str().unwrap(), "client-fixed-id");
    }
}
