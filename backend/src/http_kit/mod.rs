//! Cross-cutting HTTP helpers: JSON patch parsing, `X-Request-Id` error injection, rate limits.

pub mod json_patch;
pub mod rate_limit;
pub mod request_id_mw;
