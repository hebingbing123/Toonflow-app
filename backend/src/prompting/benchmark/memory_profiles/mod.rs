//! 记忆预算档与 ROI 证据联动。
//!
//! 本模块负责：
//! 1. 定义 `MemoryBudgetProfileSnapshot` 结构
//! 2. 关联现有记忆预算诊断与实验结果
//! 3. 输出按样本、阶段、变体的 ROI 对比摘要

use axum::{routing::get, Router};

use crate::state::AppState;

mod handlers;
mod types;

#[cfg(test)]
mod tests;

pub(crate) use handlers::{__path_get_experiment_roi, __path_list_memory_profiles};
pub use types::{
    CompressionRules, MemoryBudgetProfileSnapshot, RetentionBuckets, RoiEvidenceSummary,
    SampleRoiDetail, StageRoiBreakdown, VariantCostDelta, VariantRoiComparison,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/benchmark/memory-profiles",
            get(handlers::list_memory_profiles),
        )
        .route(
            "/api/v1/benchmark/experiments/{id}/roi",
            get(handlers::get_experiment_roi),
        )
}
