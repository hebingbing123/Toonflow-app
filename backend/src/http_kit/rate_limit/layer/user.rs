use std::sync::Arc;

use axum::http::Request;
use governor::middleware::StateInformationMiddleware;
use tower_governor::errors::GovernorError;
use tower_governor::governor::{GovernorConfig, GovernorConfigBuilder};
use tower_governor::key_extractor::{KeyExtractor, PeerIpKeyExtractor, SmartIpKeyExtractor};
use tower_governor::GovernorLayer;

use super::env::env_truthy;
use super::jwt_decode::extract_user_id_from_jwt;

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
                if let Some(token) = auth_str.strip_prefix("Bearer ") {
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

pub(crate) type UserRateLimitLayer =
    GovernorLayer<UserIdKeyExtractor, StateInformationMiddleware, axum::body::Body>;

/// Per-user rate limiting: ~10 req/s per user, burst 30.
/// Stricter than global IP-based limiting to prevent user abuse.
pub(crate) fn user_governor_layer() -> UserRateLimitLayer {
    let trust_forwarded = env_truthy("RATE_LIMIT_TRUST_FORWARDED_HEADERS");

    let config: Arc<GovernorConfig<UserIdKeyExtractor, StateInformationMiddleware>> = Arc::new(
        GovernorConfigBuilder::default()
            .key_extractor(UserIdKeyExtractor::new(trust_forwarded))
            .per_millisecond(100)
            .burst_size(30)
            .use_headers()
            .finish()
            .expect("User rate limit config must be valid"),
    );
    GovernorLayer::new(config)
}
