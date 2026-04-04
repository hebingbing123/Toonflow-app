use axum::{
    http::StatusCode,
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
    BadRequest(String),
    DatabaseError(String),
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
            ApiError::BadRequest(msg) => (StatusCode::BAD_REQUEST, "bad_request", msg.as_str()),
            ApiError::DatabaseError(msg) => (
                StatusCode::SERVICE_UNAVAILABLE,
                "database_error",
                msg.as_str(),
            ),
        };

        let body = ErrorBody {
            code: code.to_string(),
            message: message.to_string(),
            request_id: None,
        };

        (status, Json(body)).into_response()
    }
}
