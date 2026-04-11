//! 小说、小说事件、遗留小说 HTTP 和分镜模块。
//!
//! 子模块：
//! - `novels` — 小说 CRUD
//! - `events` — 小说事件
//! - `legacy` — 遗留小说接口
//! - `storyboards` — 分镜管理

pub mod events;
pub mod legacy;
pub mod novels;
pub mod storyboards;
