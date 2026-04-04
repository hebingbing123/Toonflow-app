//! Per-client-IP rate limiting via [`tower_governor`] (token bucket).
//! Tune with `RATE_LIMIT_REFILL_MS` (milliseconds between adding one token; lower = higher sustained RPS)
//! and `RATE_LIMIT_BURST` (max burst size). Excludes liveness/version routes and **`POST /api/v1/webhooks/billing`** — see [`crate::app::build_router`].
//!
//! By default the key is **peer** IP (`ConnectInfo`). Set `RATE_LIMIT_TRUST_FORWARDED_HEADERS=1` only
//! behind a **trusted** reverse proxy so the key uses `Forwarded` / `X-Forwarded-For` / `X-Real-Ip`
//! (see [`tower_governor::key_extractor::SmartIpKeyExtractor`]).

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
