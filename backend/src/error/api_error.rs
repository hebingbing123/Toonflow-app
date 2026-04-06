use axum::{
    http::{header, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;

#[derive(Serialize)]
pub struct ErrorBody {
    pub code: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub request_id: Option<String>,
}

#[derive(Debug)]
pub enum ApiError {
    Unauthorized,
    BadToken,
    AuthNotConfigured,
    NotFound,
    Conflict(String),
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
    /// HTTP **501** — capability not implemented (e.g. legacy write path without Postgres backing yet).
    NotImplemented(String),
    /// HTTP **429** — user has exceeded their plan quota (e.g. daily job limit for Free tier).
    /// Automatically adds `Retry-After` header with seconds until UTC midnight.
    QuotaExceeded(String),
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
        let (status, code, message) = match &self {
            ApiError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "unauthorized",
                "Missing or invalid Authorization header",
            ),
            ApiError::BadToken => (
                StatusCode::UNAUTHORIZED,
                "invalid_token",
                "JWT verification failed",
            ),
            ApiError::AuthNotConfigured => (
                StatusCode::SERVICE_UNAVAILABLE,
                "auth_not_configured",
                "SUPABASE_JWT_SECRET is not set",
            ),
            ApiError::NotFound => (StatusCode::NOT_FOUND, "not_found", "Resource not found"),
            ApiError::Conflict(msg) => (StatusCode::CONFLICT, "conflict", msg.as_str()),
            ApiError::BadRequest(msg) => (StatusCode::BAD_REQUEST, "bad_request", msg.as_str()),
            ApiError::DatabaseError(msg) => (
                StatusCode::SERVICE_UNAVAILABLE,
                "database_error",
                msg.as_str(),
            ),
            ApiError::WebhookNotConfigured => (
                StatusCode::SERVICE_UNAVAILABLE,
                "webhook_not_configured",
                "BILLING_WEBHOOK_SECRET is not set",
            ),
            ApiError::InvalidWebhookSignature => (
                StatusCode::UNAUTHORIZED,
                "invalid_webhook_signature",
                "HMAC verification failed",
            ),
            ApiError::Internal => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "Internal server error",
            ),
            ApiError::LlmNotConfigured => (
                StatusCode::SERVICE_UNAVAILABLE,
                "llm_not_configured",
                "LLM is not configured (set OPENAI_API_KEY or LLM_API_KEY)",
            ),
            ApiError::NotImplemented(msg) => {
                (StatusCode::NOT_IMPLEMENTED, "not_implemented", msg.as_str())
            }
            ApiError::QuotaExceeded(msg) => (
                StatusCode::TOO_MANY_REQUESTS,
                "quota_exceeded",
                msg.as_str(),
            ),
        };

        let body = ErrorBody {
            code: code.to_string(),
            message: message.to_string(),
            request_id: None,
        };

        let mut resp = (status, Json(body)).into_response();

        // Attach Retry-After for quota errors so clients know when the daily window resets.
        if matches!(self, ApiError::QuotaExceeded(_)) {
            let secs = secs_until_utc_midnight();
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
    use axum::response::IntoResponse;

    #[test]
    fn quota_exceeded_has_retry_after_header() {
        let resp = ApiError::QuotaExceeded("limit reached".into()).into_response();
        assert_eq!(resp.status(), StatusCode::TOO_MANY_REQUESTS);
        let retry = resp
            .headers()
            .get(header::RETRY_AFTER)
            .expect("Retry-After header present");
        let secs: u64 = retry.to_str().unwrap().parse().expect("numeric");
        assert!(secs > 0 && secs <= 86_400, "secs={secs}");
    }

    #[test]
    fn other_errors_have_no_retry_after_header() {
        let resp = ApiError::NotFound.into_response();
        assert!(resp.headers().get(header::RETRY_AFTER).is_none());
    }
}
