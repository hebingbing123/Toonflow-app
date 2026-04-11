//! 计量模块：使用事件和套餐层级配额（§12.3）。
//!
//! 子模块：
//! - `quota` — 配额检查和限制
//! - `usage` — 使用事件记录

pub mod quota;
pub mod usage;
