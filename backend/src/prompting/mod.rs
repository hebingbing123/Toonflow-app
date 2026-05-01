//! 用户提示词模板、质量审查 REST 和磁盘技能。
//!
//! 子模块：
//! - `prompts` — 提示词模板
//! - `quality` — 质量审查
//! - `skills` — 磁盘技能
//! - `skill_versions` — 技能文件版本管理

mod openapi;
pub mod prompts;
pub mod quality;
pub mod skill_versions;
pub mod skills;

pub use openapi::PromptingHttpOpenApi;
