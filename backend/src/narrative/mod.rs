//! 叙事模块：小说、小说事件、遗留小说 HTTP 和分镜。
//!
//! 子模块：
//! - `events` — 小说事件管理
//! - `novels` — 小说 CRUD
//! - `storyboards` — 分镜管理
//! - `legacy` — 遗留 HTTP 端点

pub mod events;
pub mod legacy;
pub mod novels;
pub mod storyboards;
