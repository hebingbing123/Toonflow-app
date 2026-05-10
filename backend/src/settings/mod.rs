//! 设置模块：遗留 `/api/setting/*` HTTP 接口。
//!
//! 包括：关于、提供商、开发开关、危险操作、内存配置、代理部署。
//! 还包括 `/api/v1/agents/memory/*`（Postgres `app_agent_memory`）。
//! 以及应用内帮助 Hub（env 驱动链接）。
//!
//! 子模块：
//! - `about` — 关于（检查更新、下载应用）
//! - `account` — 账户导出 / 删号
//! - `api_keys` — 用户级 API Key
//! - `vendors` — 提供商配置
//! - `dev` — 开发设置
//! - `danger` — 危险操作
//! - `memory_config` — 内存配置
//! - `agent_deploy` — 代理部署
//! - `agent_memory` — 代理记忆
//! - `help_hub` — 应用内帮助 Hub
//! - `notifications` — 应用内通知中心
//! - `outbound_webhooks` — 出站 Webhook
//! - `platform_config` — 平台配置 / 功能开关

pub mod about;
pub mod account;
pub mod admin_console;
pub mod agent_deploy;
pub mod agent_memory;
pub mod api_keys;
pub mod danger;
pub mod dev;
pub mod help_hub;
pub mod memory_config;
pub mod notifications;
pub mod openapi;
pub mod outbound_webhooks;
pub mod platform_config;
pub mod vendors;

pub use openapi::SettingsOpenApi;
