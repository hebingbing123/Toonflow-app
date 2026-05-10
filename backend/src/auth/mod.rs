//! 认证模块：REST 的 Bearer JWT 提取。
//!
//! WebSocket 路径使用 [`jwt::verify_supabase_user_jwt`] 验证原始令牌。

pub mod api_keys;
mod jwt;
pub mod middleware;

use axum::http::{header, HeaderMap};
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

pub use api_keys::{
    bearer_or_api_key_token, AUTH_API_KEY_ID_HEADER, AUTH_API_KEY_SCOPE_HEADER, AUTH_USER_ID_HEADER,
};
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

pub fn require_jwt_user_uuid(state: &AppState, headers: &HeaderMap) -> Result<Uuid, ApiError> {
    let claims = require_claims(state, headers)?;
    Uuid::parse_str(claims.sub.trim()).map_err(|_| ApiError::BadToken)
}

pub fn maybe_authenticated_user_uuid(
    state: &AppState,
    headers: &HeaderMap,
) -> Result<Option<Uuid>, ApiError> {
    if let Some(value) = headers
        .get(AUTH_USER_ID_HEADER)
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|v| !v.is_empty())
    {
        return Uuid::parse_str(value)
            .map(Some)
            .map_err(|_| ApiError::BadToken);
    }
    if bearer_token(headers).is_some() {
        return require_jwt_user_uuid(state, headers).map(Some);
    }
    Ok(None)
}

pub fn require_user_uuid(state: &AppState, headers: &HeaderMap) -> Result<Uuid, ApiError> {
    maybe_authenticated_user_uuid(state, headers)?.ok_or(ApiError::Unauthorized)
}
