//! 短剧质量基线与实验运营闭环。
//!
//! 子模块：
//! - `registry` — 基线样本注册表
//! - `experiments` — 实验运行与变体快照
//! - `judge` — 统一评测量表

pub mod experiments;
pub mod judge;
pub mod registry;

pub use experiments::routes as experiments_routes;
pub use judge::routes as judge_routes;
pub use registry::routes as registry_routes;
