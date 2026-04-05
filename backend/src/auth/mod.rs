//! Bearer JWT extraction for REST; WebSocket paths use [`jwt::verify_supabase_user_jwt`] with raw tokens.

mod jwt;

use axum::http::{header, HeaderMap};
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

pub use jwt::{verify_supabase_user_jwt, Claims};

pub fn bearer_token(headers: &HeaderMap) -> Option<&str> {
    let value = headers.get(header::AUTHORIZATION)?.to_str().ok()?;
    let rest = value.strip_prefix("Bearer ")?;
    let t = rest.trim();
    if t.is_empty() {
        return None;
    }
    Some(t)
}

pub fn require_claims(state: &AppState, headers: &HeaderMap) -> Result<Claims, ApiError> {
    let secret = state
        .jwt_secret
        .as_deref()
        .ok_or(ApiError::AuthNotConfigured)?;
    let token = bearer_token(headers).ok_or(ApiError::Unauthorized)?;
    jwt::verify_supabase_user_jwt(token, secret).map_err(|_| ApiError::BadToken)
}

pub fn require_user_uuid(state: &AppState, headers: &HeaderMap) -> Result<Uuid, ApiError> {
    let claims = require_claims(state, headers)?;
    Uuid::parse_str(claims.sub.trim()).map_err(|_| ApiError::BadToken)
}
