use std::fmt::Debug;
use std::net::IpAddr;
use std::sync::Arc;

use axum::http::Request;
use governor::middleware::StateInformationMiddleware;
use tower_governor::errors::GovernorError;
use tower_governor::governor::{GovernorConfig, GovernorConfigBuilder};
use tower_governor::key_extractor::{KeyExtractor, PeerIpKeyExtractor, SmartIpKeyExtractor};
use tower_governor::GovernorLayer;

#[derive(Clone, Copy, Debug)]
pub(crate) struct EnvKeyExtractor {
    trust_forwarded: bool,
}

impl KeyExtractor for EnvKeyExtractor {
    type Key = IpAddr;

    fn extract<T>(&self, req: &Request<T>) -> Result<Self::Key, GovernorError> {
        if self.trust_forwarded {
            SmartIpKeyExtractor.extract(req)
        } else {
            PeerIpKeyExtractor.extract(req)
        }
    }
}

pub(crate) type GovernorRateLimitLayer =
    GovernorLayer<EnvKeyExtractor, StateInformationMiddleware, axum::body::Body>;

fn env_truthy(name: &str) -> bool {
    std::env::var(name)
        .map(|v| {
            matches!(
                v.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            )
        })
        .unwrap_or(false)
}

/// Default: ~50 sustained req/s per IP (`1000 / 20`), burst 100.
pub(crate) fn governor_layer_from_env() -> GovernorRateLimitLayer {
    let refill_ms = std::env::var("RATE_LIMIT_REFILL_MS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(20u64);
    let burst = std::env::var("RATE_LIMIT_BURST")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(100u32);
    let trust_forwarded = env_truthy("RATE_LIMIT_TRUST_FORWARDED_HEADERS");

    let mut tmp = GovernorConfigBuilder::default();
    let mut builder = tmp.key_extractor(EnvKeyExtractor { trust_forwarded });
    builder.per_millisecond(refill_ms.max(1));
    builder.burst_size(burst.max(1));
    let mut builder = builder.use_headers();
    let config: Arc<GovernorConfig<EnvKeyExtractor, StateInformationMiddleware>> = Arc::new(
        builder
            .finish()
            .expect("RATE_LIMIT_REFILL_MS and RATE_LIMIT_BURST must be valid"),
    );
    GovernorLayer::new(config)
}

// =============================================================================
// Layer 2: Per-user rate limiting (JWT-based)
// =============================================================================

/// Key extractor for per-user rate limiting based on JWT token.
/// Falls back to IP address if no valid JWT is present.
#[derive(Clone, Copy, Debug)]
pub(crate) struct UserIdKeyExtractor {
    trust_forwarded: bool,
}

impl UserIdKeyExtractor {
    pub(crate) fn new(trust_forwarded: bool) -> Self {
        Self { trust_forwarded }
    }
}

impl KeyExtractor for UserIdKeyExtractor {
    // Key format: "user:{uuid}" or "ip:{ip_addr}" for anonymous users
    type Key = String;

    fn extract<T>(&self, req: &Request<T>) -> Result<Self::Key, GovernorError> {
        // Try to extract user_id from Authorization header (JWT)
        if let Some(auth_header) = req.headers().get("authorization") {
            if let Ok(auth_str) = auth_header.to_str() {
                if auth_str.starts_with("Bearer ") {
                    let token = &auth_str[7..];
                    // Decode JWT payload to extract user_id
                    if let Some(user_id) = extract_user_id_from_jwt(token) {
                        return Ok(format!("user:{}", user_id));
                    }
                }
            }
        }

        // Fallback to IP-based key for anonymous users
        let ip_key = if self.trust_forwarded {
            SmartIpKeyExtractor.extract(req)?
        } else {
            PeerIpKeyExtractor.extract(req)?
        };
        Ok(format!("ip:{}", ip_key))
    }
}

/// Extract user_id from JWT token payload.
/// Note: This only decodes the payload without verification - safe for rate limiting
/// because the actual JWT verification happens in the auth middleware.
fn extract_user_id_from_jwt(token: &str) -> Option<String> {
    // JWT format: header.payload.signature
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        return None;
    }

    // Decode base64url payload
    let payload = parts[1];
    let decoded = base64_url_decode(payload).ok()?;
    let json: serde_json::Value = serde_json::from_slice(&decoded).ok()?;

    // Extract sub (subject) as user_id
    json.get("sub")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

fn base64_url_decode(input: &str) -> Result<Vec<u8>, base64::DecodeError> {
    // Replace URL-safe characters and add padding
    let normalized = input.replace('-', "+").replace('_', "/");
    let padding_needed = (4 - normalized.len() % 4) % 4;
    let padded = format!("{}{}", normalized, "=".repeat(padding_needed));
    base64::decode(padded)
}

pub(crate) type UserRateLimitLayer =
    GovernorLayer<UserIdKeyExtractor, StateInformationMiddleware, axum::body::Body>;

/// Per-user rate limiting: ~10 req/s per user, burst 30.
/// Stricter than global IP-based limiting to prevent user abuse.
pub(crate) fn user_governor_layer() -> UserRateLimitLayer {
    let trust_forwarded = env_truthy("RATE_LIMIT_TRUST_FORWARDED_HEADERS");

    let mut builder = GovernorConfigBuilder::default();
    builder.key_extractor(UserIdKeyExtractor::new(trust_forwarded));
    builder.per_millisecond(100); // 10 req/s per user
    builder.burst_size(30); // burst 30
    builder.use_headers();
    let config: Arc<GovernorConfig<UserIdKeyExtractor, StateInformationMiddleware>> = Arc::new(
        builder
            .finish()
            .expect("User rate limit config must be valid"),
    );
    GovernorLayer::new(config)
}

// =============================================================================
// Layer 3: Per-endpoint rate limiting (strict for high-frequency endpoints)
// =============================================================================

/// Key extractor that combines endpoint path with user/IP.
#[derive(Clone, Copy, Debug)]
pub(crate) struct EndpointKeyExtractor {
    trust_forwarded: bool,
}

impl EndpointKeyExtractor {
    pub(crate) fn new(trust_forwarded: bool) -> Self {
        Self { trust_forwarded }
    }
}

impl KeyExtractor for EndpointKeyExtractor {
    // Key format: "{endpoint}:{user_id}" or "{endpoint}:ip:{ip_addr}"
    type Key = String;

    fn extract<T>(&self, req: &Request<T>) -> Result<Self::Key, GovernorError> {
        let endpoint = req.uri().path();

        // Try to extract user_id from JWT
        if let Some(auth_header) = req.headers().get("authorization") {
            if let Ok(auth_str) = auth_header.to_str() {
                if auth_str.starts_with("Bearer ") {
                    let token = &auth_str[7..];
                    if let Some(user_id) = extract_user_id_from_jwt(token) {
                        return Ok(format!("{}:user:{}", endpoint, user_id));
                    }
                }
            }
        }

        // Fallback to IP
        let ip_key = if self.trust_forwarded {
            SmartIpKeyExtractor.extract(req)?
        } else {
            PeerIpKeyExtractor.extract(req)?
        };
        Ok(format!("{}:ip:{}", endpoint, ip_key))
    }
}

pub(crate) type EndpointRateLimitLayer =
    GovernorLayer<EndpointKeyExtractor, StateInformationMiddleware, axum::body::Body>;

/// Strict endpoint rate limiting: ~5 req/s per endpoint per user, burst 10.
/// For high-frequency endpoints like jobs, harness.
pub(crate) fn strict_endpoint_governor_layer() -> EndpointRateLimitLayer {
    let trust_forwarded = env_truthy("RATE_LIMIT_TRUST_FORWARDED_HEADERS");

    let mut builder = GovernorConfigBuilder::default();
    builder.key_extractor(EndpointKeyExtractor::new(trust_forwarded));
    builder.per_millisecond(200); // 5 req/s per endpoint
    builder.burst_size(10); // burst 10
    builder.use_headers();
    let config: Arc<GovernorConfig<EndpointKeyExtractor, StateInformationMiddleware>> = Arc::new(
        builder
            .finish()
            .expect("Endpoint rate limit config must be valid"),
    );
    GovernorLayer::new(config)
}
