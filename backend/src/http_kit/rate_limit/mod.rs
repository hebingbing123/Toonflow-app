//! 多层速率限制模块（基于 `tower_governor` 令牌桶）。
//!
//! ## 第一层：基于 IP 的全局速率限制
//! 默认：每个 IP 约 50 req/s（`1000 / 20`），突发 100。
//! 通过 `RATE_LIMIT_REFILL_MS` 和 `RATE_LIMIT_BURST` 调整。
//! 仅在受信任的反向代理后设置 `RATE_LIMIT_TRUST_FORWARDED_HEADERS=1`。
//!
//! ## 第二层：基于用户的速率限制（JWT）
//! 每个用户约 10 req/s，突发 30。更严格以防止用户滥用。
//! 匿名用户回退到 IP。
//!
//! ## 第三层：基于端点的速率限制（严格）
//! 每个端点每个用户约 5 req/s，突发 10。
//! 用于高频端点如 jobs、harness。
//!
//! 排除健康检查/版本/探测路由和 `POST /api/v1/webhooks/billing`。

mod layer;

pub(crate) use layer::{
    governor_layer_from_env, strict_endpoint_governor_layer, user_governor_layer,
};
