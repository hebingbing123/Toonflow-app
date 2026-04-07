//! Multi-layer rate limiting via [`tower_governor`] (token bucket).
//!
//! ## Layer 1: Global IP-based rate limiting
//! Default: ~50 req/s per IP (`1000 / 20`), burst 100.
//! Tune with `RATE_LIMIT_REFILL_MS` and `RATE_LIMIT_BURST`.
//! Set `RATE_LIMIT_TRUST_FORWARDED_HEADERS=1` only behind a trusted reverse proxy.
//!
//! ## Layer 2: Per-user rate limiting (JWT-based)
//! ~10 req/s per user, burst 30. Stricter to prevent user abuse.
//! Falls back to IP for anonymous users.
//!
//! ## Layer 3: Per-endpoint rate limiting (strict)
//! ~5 req/s per endpoint per user, burst 10.
//! For high-frequency endpoints like jobs, harness.
//!
//! Excludes liveness/version/ping routes and **`POST /api/v1/webhooks/billing`**.

mod layer;

pub(crate) use layer::{
    governor_layer_from_env, strict_endpoint_governor_layer, user_governor_layer,
    EndpointRateLimitLayer, GovernorRateLimitLayer, UserRateLimitLayer,
};
