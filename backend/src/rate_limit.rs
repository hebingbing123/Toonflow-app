//! Per-client-IP rate limiting via [`tower_governor`] (token bucket).
//! Tune with `RATE_LIMIT_REFILL_MS` (milliseconds between adding one token; lower = higher sustained RPS)
//! and `RATE_LIMIT_BURST` (max burst size). Excludes liveness routes — see [`crate::app::build_router`].

use std::sync::Arc;

use governor::middleware::StateInformationMiddleware;
use tower_governor::governor::{GovernorConfig, GovernorConfigBuilder};
use tower_governor::key_extractor::PeerIpKeyExtractor;
use tower_governor::GovernorLayer;

pub type GovernorRateLimitLayer =
    GovernorLayer<PeerIpKeyExtractor, StateInformationMiddleware, axum::body::Body>;

/// Default: ~50 sustained req/s per IP (`1000 / 20`), burst 100.
pub fn governor_layer_from_env() -> GovernorRateLimitLayer {
    let refill_ms = std::env::var("RATE_LIMIT_REFILL_MS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(20u64);
    let burst = std::env::var("RATE_LIMIT_BURST")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(100u32);

    let mut builder = GovernorConfigBuilder::default();
    builder.per_millisecond(refill_ms.max(1));
    builder.burst_size(burst.max(1));
    let mut builder = builder.use_headers();
    let config: Arc<GovernorConfig<PeerIpKeyExtractor, StateInformationMiddleware>> = Arc::new(
        builder
            .finish()
            .expect("RATE_LIMIT_REFILL_MS and RATE_LIMIT_BURST must be valid"),
    );
    GovernorLayer::new(config)
}
