//! API 错误类型定义。
//!
//! 定义 HTTP API 的错误响应类型，包括错误体结构和常用错误枚举。

use axum::{
    http::{header, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Serialize, ToSchema)]
pub struct ErrorBody {
    /// HTTP status code (e.g., 400, 404, 409, 500)
    pub status: u16,
    /// Machine-readable error code (e.g., "validation_error", "not_found", "conflict")
    pub code: String,
    /// Human-readable error message
    pub message: String,
    /// Request ID for tracing and debugging (injected by middleware)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub request_id: Option<String>,
    /// Optional additional context (e.g., field-specific validation errors, version conflicts)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<serde_json::Value>,
    /// Milliseconds until the rate-limit / quota window resets. Present on **429** responses.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub retry_after_ms: Option<u64>,
}

#[derive(Debug)]
pub enum ApiError {
    Unauthorized,
    BadToken,
    AuthNotConfigured,
    NotFound,
    Conflict(String),
    /// Conflict with optional details (e.g., version conflict with expected/current versions)
    ConflictWithDetails {
        message: String,
        details: serde_json::Value,
    },
    BadRequest(String),
    DatabaseError(String),
    /// `BILLING_WEBHOOK_SECRET` unset — webhook ingestion disabled.
    WebhookNotConfigured,
    /// HMAC did not match body (or bad `X-Toonflow-Signature` format).
    InvalidWebhookSignature,
    /// Unexpected failure (logged server-side); avoid leaking internals to clients.
    Internal,
    /// `OPENAI_API_KEY` / `LLM_API_KEY` not set — script extract and WS agent flows need it.
    LlmNotConfigured,
    /// HTTP **501** — capability not implemented (e.g. deprecated write path without Postgres backing yet).
    NotImplemented(String),
    /// HTTP **429** — user has exceeded their plan quota (e.g. daily job limit for Free tier).
    /// Automatically adds `Retry-After` header (seconds) and `retry_after_ms` in body.
    QuotaExceeded(String),
    /// HTTP **403** — authenticated but not allowed (e.g. ops-only endpoint with env gate off).
    Forbidden(String),
}

/// Seconds remaining until the next UTC midnight (quota reset point).
fn secs_until_utc_midnight() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let secs_in_day: u64 = 86_400;
    let elapsed_today = now % secs_in_day;
    secs_in_day - elapsed_today
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, code, message, details) = match &self {
            ApiError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "unauthorized",
                "Missing or invalid Authorization header",
                None,
            ),
            ApiError::BadToken => (
                StatusCode::UNAUTHORIZED,
                "invalid_token",
                "JWT verification failed",
                None,
            ),
            ApiError::AuthNotConfigured => (
                StatusCode::SERVICE_UNAVAILABLE,
                "auth_not_configured",
                "SUPABASE_JWT_SECRET is not set",
                None,
            ),
            ApiError::NotFound => (
                StatusCode::NOT_FOUND,
                "not_found",
                "Resource not found",
                None,
            ),
            ApiError::Conflict(msg) => (StatusCode::CONFLICT, "conflict", msg.as_str(), None),
            ApiError::ConflictWithDetails { message, details } => (
                StatusCode::CONFLICT,
                "conflict",
                message.as_str(),
                Some(details.clone()),
            ),
            ApiError::BadRequest(msg) => {
                (StatusCode::BAD_REQUEST, "bad_request", msg.as_str(), None)
            }
            ApiError::DatabaseError(msg) => (
                StatusCode::SERVICE_UNAVAILABLE,
                "database_error",
                msg.as_str(),
                None,
            ),
            ApiError::WebhookNotConfigured => (
                StatusCode::SERVICE_UNAVAILABLE,
                "webhook_not_configured",
                "BILLING_WEBHOOK_SECRET is not set",
                None,
            ),
            ApiError::InvalidWebhookSignature => (
                StatusCode::UNAUTHORIZED,
                "invalid_webhook_signature",
                "HMAC verification failed",
                None,
            ),
            ApiError::Internal => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "Internal server error",
                None,
            ),
            ApiError::LlmNotConfigured => (
                StatusCode::SERVICE_UNAVAILABLE,
                "llm_not_configured",
                "LLM is not configured (set OPENAI_API_KEY or LLM_API_KEY)",
                None,
            ),
            ApiError::NotImplemented(msg) => (
                StatusCode::NOT_IMPLEMENTED,
                "not_implemented",
                msg.as_str(),
                None,
            ),
            ApiError::QuotaExceeded(msg) => (
                StatusCode::TOO_MANY_REQUESTS,
                "quota_exceeded",
                msg.as_str(),
                None,
            ),
            ApiError::Forbidden(msg) => (StatusCode::FORBIDDEN, "forbidden", msg.as_str(), None),
        };

        let is_quota = matches!(self, ApiError::QuotaExceeded(_));
        let retry_secs = if is_quota {
            Some(secs_until_utc_midnight())
        } else {
            None
        };

        let body = ErrorBody {
            status: status.as_u16(),
            code: code.to_string(),
            message: message.to_string(),
            request_id: None,
            details,
            retry_after_ms: retry_secs.map(|s| s * 1_000),
        };

        let mut resp = (status, Json(body)).into_response();

        // Also set the standard Retry-After header (seconds) for HTTP clients.
        if let Some(secs) = retry_secs {
            if let Ok(val) = HeaderValue::from_str(&secs.to_string()) {
                resp.headers_mut().insert(header::RETRY_AFTER, val);
            }
        }

        resp
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::to_bytes;
    use axum::response::IntoResponse;
    use proptest::prelude::*;

    fn decode_error_body(resp: Response) -> serde_json::Value {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");
        let bytes = runtime
            .block_on(to_bytes(resp.into_body(), 16 * 1024))
            .expect("body bytes");
        serde_json::from_slice(&bytes).expect("json body")
    }

    #[test]
    fn quota_exceeded_has_retry_after_header_and_body_ms() {
        let resp = ApiError::QuotaExceeded("limit reached".into()).into_response();
        assert_eq!(resp.status(), StatusCode::TOO_MANY_REQUESTS);
        let retry_hdr = resp
            .headers()
            .get(header::RETRY_AFTER)
            .expect("Retry-After header present");
        let secs: u64 = retry_hdr.to_str().unwrap().parse().expect("numeric");
        assert!(secs > 0 && secs <= 86_400, "secs={secs}");

        let body = decode_error_body(resp);
        assert_eq!(
            body.get("status").and_then(serde_json::Value::as_u64),
            Some(429)
        );
    }

    #[test]
    fn other_errors_have_no_retry_after_header() {
        let resp = ApiError::NotFound.into_response();
        assert!(resp.headers().get(header::RETRY_AFTER).is_none());
    }

    #[test]
    fn error_body_includes_status_field() {
        let resp = ApiError::BadRequest("invalid input".into()).into_response();
        let body = decode_error_body(resp);
        assert_eq!(
            body.get("status").and_then(serde_json::Value::as_u64),
            Some(400)
        );
        assert_eq!(
            body.get("code").and_then(serde_json::Value::as_str),
            Some("bad_request")
        );
        assert_eq!(
            body.get("message").and_then(serde_json::Value::as_str),
            Some("invalid input")
        );
    }

    #[test]
    fn conflict_with_details_includes_details_field() {
        let resp = ApiError::ConflictWithDetails {
            message: "Version conflict".to_string(),
            details: serde_json::json!({
                "expected_version": "v1",
                "current_version": "v2",
                "conflict_type": "version_mismatch"
            }),
        }
        .into_response();

        let body = decode_error_body(resp);
        assert_eq!(
            body.get("status").and_then(serde_json::Value::as_u64),
            Some(409)
        );
        assert_eq!(
            body.get("code").and_then(serde_json::Value::as_str),
            Some("conflict")
        );
        assert_eq!(
            body.get("message").and_then(serde_json::Value::as_str),
            Some("Version conflict")
        );

        let details = body.get("details").expect("details should be present");
        assert_eq!(
            details
                .get("expected_version")
                .and_then(serde_json::Value::as_str),
            Some("v1")
        );
        assert_eq!(
            details
                .get("current_version")
                .and_then(serde_json::Value::as_str),
            Some("v2")
        );
        assert_eq!(
            details
                .get("conflict_type")
                .and_then(serde_json::Value::as_str),
            Some("version_mismatch")
        );
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(20))]

        // Feature: drama-platform-completion, Property 14: 429 等待信息完整性
        // 验证：需求 18.5
        #[test]
        fn prop_quota_exceeded_response_keeps_retry_header_and_body_in_sync(
            message in ".{1,48}",
        ) {
            let resp = ApiError::QuotaExceeded(message).into_response();
            let retry_hdr = resp
                .headers()
                .get(header::RETRY_AFTER)
                .expect("Retry-After header present")
                .to_str()
                .expect("header str")
                .parse::<u64>()
                .expect("numeric retry-after");
            let body = decode_error_body(resp);
            let retry_after_ms = body
                .get("retry_after_ms")
                .and_then(serde_json::Value::as_u64)
                .expect("retry_after_ms present");

            prop_assert!(retry_hdr > 0 && retry_hdr <= 86_400);
            prop_assert_eq!(retry_after_ms, retry_hdr * 1_000);
            prop_assert_eq!(
                body.get("code").and_then(serde_json::Value::as_str),
                Some("quota_exceeded")
            );
            prop_assert_eq!(
                body.get("status").and_then(serde_json::Value::as_u64),
                Some(429)
            );
        }
    }
}
