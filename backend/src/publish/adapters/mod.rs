//! **F7/F8** adapter routing: nine-platform sandbox closures (domestic + overseas).
//!
//! **P1 真实能力分层（sandbox/live/manual_bridge）**：
//! - `sandbox`: 演示/测试模式，不实际投递到平台，返回模拟成功
//! - `live`: 真实 API 投递，直接调用平台接口
//! - `manual_bridge`: 人工辅助投递，需要人工确认后通过桥接完成
//!
//! **重要约束**：sandbox 成功 ≠ 真实发布成功；审计与结果展示须明确区分 delivery_mode。

use serde_json::Value;

use super::types::{PublishDraftRow, PublishJobRow, PublishTargetRow};

mod live;
mod manual_bridge;
mod metrics;
mod routing;
mod sandbox;

#[cfg(test)]
mod tests;

// Re-export public items
pub(crate) use live::run_live_adapter;
pub(crate) use manual_bridge::run_manual_bridge_adapter;
pub(crate) use metrics::fetch_platform_metrics;
pub(crate) use routing::route_for_mode;
pub(crate) use sandbox::run_sandbox_adapter;

/// Adapter 执行结果，包含 delivery_mode 用于区分真实能力层级
pub(crate) struct PublishAdapterResult {
    pub(crate) status: &'static str,
    /// detail 中必须包含 `delivery_mode` 字段（sandbox/live/manual_bridge）
    pub(crate) detail: Value,
    pub(crate) error_message: Option<String>,
}

/// Main entry point for adapter routing
pub(crate) fn run_target_adapter(
    job: &PublishJobRow,
    draft: &PublishDraftRow,
    target: &PublishTargetRow,
) -> PublishAdapterResult {
    let route = route_for_mode(&target.automation_mode);

    match route.route_key {
        "live" => run_live_adapter(job, draft, target),
        "manual_bridge" => run_manual_bridge_adapter(job, draft, target),
        _ => run_sandbox_adapter(job, draft, target),
    }
}
