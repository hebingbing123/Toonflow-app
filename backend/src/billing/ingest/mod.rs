//! 幂等性 Webhook 行插入 + 可选的 `app_user_profile` 更新。
//!
//! 处理计费 Webhook 事件，支持 Stripe、支付宝等提供商。
//! 子模块：
//! - `subscription_state` — 订阅状态管理
//! - `apply_plan` — 应用计费计划
//! - `webhook_ingest` — Webhook 摄取主逻辑
//! - `event_parse` — 事件解析

mod apply_plan;
mod event_parse;
mod subscription_state;
mod webhook_ingest;

#[cfg(test)]
mod tests;

pub(crate) use webhook_ingest::ingest_webhook;
