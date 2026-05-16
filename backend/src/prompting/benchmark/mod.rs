//! 短剧质量基线与实验运营闭环。
//!
//! 子模块：
//! - `registry` — 基线样本注册表
//! - `experiments` — 实验运行与变体快照
//! - `judge` — 统一评测量表
//! - `review_queue` — 人工复核队列
//! - `observation_assets` — 观察资产治理
//! - `memory_profiles` — 记忆预算档与 ROI 证据
//! - `promotion_gate` — 放行门与趋势

pub mod experiments;
pub mod judge;
pub mod memory_profiles;
pub mod observation_assets;
pub mod promotion_gate;
pub mod registry;
pub mod review_queue;

#[cfg(test)]
mod property_tests;

pub use experiments::routes as experiments_routes;
pub use judge::routes as judge_routes;
pub use memory_profiles::routes as memory_profiles_routes;
pub use observation_assets::routes as observation_assets_routes;
pub use promotion_gate::routes as promotion_gate_routes;
pub use registry::routes as registry_routes;
pub use review_queue::routes as review_queue_routes;
