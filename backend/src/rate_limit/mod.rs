//! Per-client-IP rate limiting via [`tower_governor`] (token bucket).
//! Tune with `RATE_LIMIT_REFILL_MS` (milliseconds between adding one token; lower = higher sustained RPS)
//! and `RATE_LIMIT_BURST` (max burst size). Excludes liveness/version/ping routes and **`POST /api/v1/webhooks/billing`** — see [`crate::app::build_router`].
//!
//! By default the key is **peer** IP (`ConnectInfo`). Set `RATE_LIMIT_TRUST_FORWARDED_HEADERS=1` only
//! behind a **trusted** reverse proxy so the key uses `Forwarded` / `X-Forwarded-For` / `X-Real-Ip`
//! (see [`tower_governor::key_extractor::SmartIpKeyExtractor`]).

mod layer;

pub(crate) use layer::governor_layer_from_env;
