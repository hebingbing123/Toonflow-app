use std::sync::Arc;

use axum::http::Request;
use governor::middleware::StateInformationMiddleware;
use tower_governor::errors::GovernorError;
use tower_governor::governor::{GovernorConfig, GovernorConfigBuilder};
use tower_governor::key_extractor::{KeyExtractor, PeerIpKeyExtractor, SmartIpKeyExtractor};
use tower_governor::GovernorLayer;

use super::env::env_truthy;
use super::jwt_decode::extract_user_id_from_jwt;

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
                if let Some(token) = auth_str.strip_prefix("Bearer ") {
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

    let config: Arc<GovernorConfig<EndpointKeyExtractor, StateInformationMiddleware>> = Arc::new(
        GovernorConfigBuilder::default()
            .key_extractor(EndpointKeyExtractor::new(trust_forwarded))
            .per_millisecond(200)
            .burst_size(10)
            .use_headers()
            .finish()
            .expect("Endpoint rate limit config must be valid"),
    );
    GovernorLayer::new(config)
}
