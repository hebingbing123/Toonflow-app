use axum::http::{header, HeaderMap};
use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct Claims {
    pub sub: String,
    // Present for JWT deserialization; validated by `jsonwebtoken::Validation`.
    #[allow(dead_code)]
    exp: i64,
    pub email: Option<String>,
}

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
    verify_supabase_user_jwt(token, secret).map_err(|_| ApiError::BadToken)
}

pub fn require_user_uuid(state: &AppState, headers: &HeaderMap) -> Result<Uuid, ApiError> {
    let claims = require_claims(state, headers)?;
    Uuid::parse_str(claims.sub.trim()).map_err(|_| ApiError::BadToken)
}

pub fn verify_supabase_user_jwt(
    token: &str,
    secret: &[u8],
) -> Result<Claims, jsonwebtoken::errors::Error> {
    let mut validation = Validation::new(Algorithm::HS256);
    validation.validate_exp = true;
    validation.set_audience(&["authenticated"]);

    let key = DecodingKey::from_secret(secret);
    let data = decode::<Claims>(token, &key, &validation)?;
    Ok(data.claims)
}
