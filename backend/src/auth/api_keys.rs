use axum::http::{header, HeaderMap, HeaderValue, Method, Request};
use hmac::{Hmac, Mac};
use serde::Serialize;
use sha2::Sha256;
use sqlx::FromRow;
use subtle::ConstantTimeEq;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

pub const AUTH_USER_ID_HEADER: &str = "x-toonflow-auth-user-id";
pub const AUTH_API_KEY_ID_HEADER: &str = "x-toonflow-auth-api-key-id";
pub const AUTH_API_KEY_SCOPE_HEADER: &str = "x-toonflow-auth-api-key-scope";

const API_KEY_PREFIX: &str = "tfk_";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ApiKeyScope {
    ReadOnly,
    ReadWrite,
}

impl ApiKeyScope {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::ReadOnly => "read_only",
            Self::ReadWrite => "read_write",
        }
    }

    pub fn parse(raw: &str) -> Option<Self> {
        match raw.trim() {
            "read_only" => Some(Self::ReadOnly),
            "read_write" => Some(Self::ReadWrite),
            _ => None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct ParsedApiKeyToken<'a> {
    pub public_id: &'a str,
    pub secret: &'a str,
}

#[derive(Debug, Clone, FromRow)]
pub struct ApiKeyAuthRow {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub scope: String,
    pub status: String,
    pub secret_hash: String,
    pub expires_at: Option<chrono::DateTime<chrono::Utc>>,
}

type HmacSha256 = Hmac<Sha256>;

pub fn bearer_or_api_key_token(headers: &HeaderMap) -> Option<&str> {
    if let Some(value) = headers
        .get("x-api-key")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|v| !v.is_empty())
    {
        return Some(value);
    }
    let value = headers.get(header::AUTHORIZATION)?.to_str().ok()?;
    let rest = value.strip_prefix("Bearer ")?;
    let token = rest.trim();
    if token.is_empty() {
        None
    } else {
        Some(token)
    }
}

pub fn parse_api_key_token(token: &str) -> Option<ParsedApiKeyToken<'_>> {
    let rest = token.strip_prefix(API_KEY_PREFIX)?;
    let (public_id, secret) = rest.split_once('_')?;
    if public_id.len() < 8
        || secret.len() < 16
        || !public_id.chars().all(|c| c.is_ascii_hexdigit())
        || !secret.chars().all(|c| c.is_ascii_hexdigit())
    {
        return None;
    }
    Some(ParsedApiKeyToken { public_id, secret })
}

pub fn public_id_from_request<T>(req: &Request<T>) -> Option<String> {
    bearer_or_api_key_token(req.headers())
        .and_then(parse_api_key_token)
        .map(|parsed| parsed.public_id.to_string())
}

pub fn hash_api_key_secret(state: &AppState, secret: &str) -> Result<String, ApiError> {
    let secret_material = std::env::var("TOONFLOW_API_KEY_PEPPER")
        .ok()
        .map(|value| value.into_bytes())
        .or_else(|| state.jwt_secret.clone())
        .ok_or(ApiError::AuthNotConfigured)?;
    let mut mac = HmacSha256::new_from_slice(&secret_material).map_err(|_| ApiError::Internal)?;
    mac.update(secret.as_bytes());
    Ok(hex::encode(mac.finalize().into_bytes()))
}

pub fn generate_api_key_secret_material(state: &AppState) -> Result<(String, String), ApiError> {
    let secret_bytes: [u8; 24] = rand::random();
    let secret = hex::encode(secret_bytes);
    let hash = hash_api_key_secret(state, &secret)?;
    Ok((secret, hash))
}

pub fn compose_api_key_token(public_id: &str, secret: &str) -> String {
    format!("{API_KEY_PREFIX}{public_id}_{secret}")
}

pub fn key_hint_from_secret(public_id: &str, secret: &str) -> String {
    format!("tfk_{public_id}_...{}", &secret[secret.len() - 4..])
}

pub fn generate_api_key_material(
    state: &AppState,
) -> Result<(String, String, String, String), ApiError> {
    let public_bytes: [u8; 6] = rand::random();
    let public_id = hex::encode(public_bytes);
    let (secret, hash) = generate_api_key_secret_material(state)?;
    let token = compose_api_key_token(&public_id, &secret);
    let key_hint = key_hint_from_secret(&public_id, &secret);
    Ok((public_id, token, hash, key_hint))
}

pub async fn resolve_api_key_request(
    state: &AppState,
    token: &str,
) -> Result<Option<(Uuid, Uuid, ApiKeyScope)>, ApiError> {
    let Some(parsed) = parse_api_key_token(token) else {
        return Ok(None);
    };
    let pool = state.require_pool()?;
    let row = sqlx::query_as::<_, ApiKeyAuthRow>(
        r#"
        SELECT id, owner_user_id, scope, status, secret_hash, expires_at
        FROM public.app_api_key
        WHERE public_id = $1
        "#,
    )
    .bind(parsed.public_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(row) = row else {
        return Err(ApiError::BadToken);
    };
    let expected = hash_api_key_secret(state, parsed.secret)?;
    if row
        .secret_hash
        .as_bytes()
        .ct_eq(expected.as_bytes())
        .unwrap_u8()
        != 1
    {
        return Err(ApiError::BadToken);
    }
    if row.status != "active" {
        return Err(ApiError::BadToken);
    }
    if row.expires_at.is_some_and(|ts| ts <= chrono::Utc::now()) {
        return Err(ApiError::BadToken);
    }
    let scope = ApiKeyScope::parse(&row.scope).ok_or(ApiError::Internal)?;
    Ok(Some((row.id, row.owner_user_id, scope)))
}

pub async fn touch_api_key_usage(
    state: &AppState,
    api_key_id: Uuid,
    method: &Method,
    path: &str,
    headers: &HeaderMap,
) -> Result<(), ApiError> {
    let pool = state.require_pool()?;
    let ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.split(',').next().unwrap_or("").trim().to_string())
        .filter(|s| !s.is_empty());
    let user_agent = headers
        .get(header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(str::to_string);
    sqlx::query(
        r#"
        UPDATE public.app_api_key
        SET
          last_used_at = NOW(),
          last_used_path = $2,
          last_used_method = $3,
          last_used_ip = $4,
          last_used_user_agent = $5,
          use_count = use_count + 1,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(api_key_id)
    .bind(path)
    .bind(method.as_str())
    .bind(ip)
    .bind(user_agent)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub fn inject_auth_headers(
    headers: &mut HeaderMap,
    user_id: Uuid,
    api_key_id: Uuid,
    scope: ApiKeyScope,
) -> Result<(), ApiError> {
    headers.insert(
        AUTH_USER_ID_HEADER,
        HeaderValue::from_str(&user_id.to_string()).map_err(|_| ApiError::Internal)?,
    );
    headers.insert(
        AUTH_API_KEY_ID_HEADER,
        HeaderValue::from_str(&api_key_id.to_string()).map_err(|_| ApiError::Internal)?,
    );
    headers.insert(
        AUTH_API_KEY_SCOPE_HEADER,
        HeaderValue::from_str(scope.as_str()).map_err(|_| ApiError::Internal)?,
    );
    Ok(())
}
