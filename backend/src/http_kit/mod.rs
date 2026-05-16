//! Cross-cutting HTTP helpers: JSON patch parsing, `X-Request-Id` error injection, rate limits, request deduplication, metrics.

pub mod json_patch;
pub mod metrics;
pub mod rate_limit;
pub mod request_dedupe;
pub mod request_id_mw;
