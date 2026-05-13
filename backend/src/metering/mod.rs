//! 使用事件和套餐层级配额（§12.3）。
//!
//! 子模块：
//! - `billing_context` — 计费上下文解析（用户 vs workspace）
//! - `quota` — 配额管理
//! - `usage` — 使用计量
//! - `llm_usage` — LLM token 用量追踪

pub mod billing_context;
pub mod llm_usage;
pub mod quota;
pub mod usage;

pub use billing_context::{
    get_effective_billing_context, resolve_billing_scope, BillingConfig, BillingScope,
    EffectiveBillingContext,
};
pub use quota::quota_metrics_snapshot;
pub use usage::MeteringOpenApi;
