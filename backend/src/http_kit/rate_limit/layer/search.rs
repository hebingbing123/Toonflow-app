//! 搜索端点专用速率限制：60 请求/分钟（1 req/s）。

use std::sync::Arc;

use axum::http::Request;
use governor::middleware::StateInformationMiddleware;
use tower_governor::errors::GovernorError;
use tower_governor::governor::{GovernorConfig, GovernorConfigBuilder};
use tower_governor::key_extractor::{KeyExtractor, PeerIpKeyExtractor, SmartIpKeyExtractor};
use tower_governor::GovernorLayer;

use crate::auth::api_keys::public_id_from_request;

use super::env::env_truthy;
use super::jwt_decode::extract_user_id_from_jwt;

/// Key extractor for search endpoint rate limiting based on user ID.
/// Falls back to IP address if no valid JWT is present.
#[derive(Clone, Copy, Debug)]
pub(crate) struct SearchKeyExtractor {
    trust_forwarded: bool,
}

impl SearchKeyExtractor {
    pub(crate) fn new(trust_forwarded: bool) -> Self {
        Self { trust_forwarded }
    }
}

impl KeyExtractor for SearchKeyExtractor {
    // Key format: "search:user:{uuid}" or "search:ip:{ip_addr}"
    type Key = String;

    fn extract<T>(&self, req: &Request<T>) -> Result<Self::Key, GovernorError> {
        if let Some(public_id) = public_id_from_request(req) {
            return Ok(format!("search:api_key:{}", public_id));
        }
        // Try to extract user_id from Authorization header (JWT)
        if let Some(auth_header) = req.headers().get("authorization") {
            if let Ok(auth_str) = auth_header.to_str() {
                if let Some(token) = auth_str.strip_prefix("Bearer ") {
                    // Decode JWT payload to extract user_id
                    if let Some(user_id) = extract_user_id_from_jwt(token) {
                        return Ok(format!("search:user:{}", user_id));
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
        Ok(format!("search:ip:{}", ip_key))
    }
}

pub(crate) type SearchRateLimitLayer =
    GovernorLayer<SearchKeyExtractor, StateInformationMiddleware, axum::body::Body>;

/// Search endpoint rate limiting: 60 req/min = 1 req/s per user, burst 5.
/// Requirement 9.7: 配置速率限制（60 请求/分钟）
pub(crate) fn search_governor_layer() -> SearchRateLimitLayer {
    let trust_forwarded = env_truthy("RATE_LIMIT_TRUST_FORWARDED_HEADERS");

    let config: Arc<GovernorConfig<SearchKeyExtractor, StateInformationMiddleware>> = Arc::new(
        GovernorConfigBuilder::default()
            .key_extractor(SearchKeyExtractor::new(trust_forwarded))
            .per_millisecond(1000) // 1 request per second = 60 per minute
            .burst_size(5) // Allow small bursts
            .use_headers()
            .finish()
            .expect("Search rate limit config must be valid"),
    );
    GovernorLayer::new(config)
}
