//! 设置模块：遗留 `/api/setting/*` HTTP 接口。
//!
//! 包括：关于、提供商、开发开关、危险操作、内存配置、代理部署。
//! 还包括 `/api/v1/agents/memory/*`（Postgres `app_agent_memory`）。
//! 以及应用内帮助 Hub（env 驱动链接）。
//!
//! 子模块：
//! - `about` — 关于（检查更新、下载应用）
//! - `vendors` — 提供商配置
//! - `dev` — 开发设置
//! - `danger` — 危险操作
//! - `memory_config` — 内存配置
//! - `agent_deploy` — 代理部署
//! - `agent_memory` — 代理记忆
//! - `help_hub` — 应用内帮助 Hub

pub mod about;
pub mod agent_deploy;
pub mod agent_memory;
pub mod danger;
pub mod dev;
pub mod help_hub;
pub mod memory_config;
pub mod openapi;
pub mod vendors;

pub use openapi::SettingsOpenApi;
