//! 设置模块：遗留 `/api/setting/*` HTTP 接口。
//!
//! 包含关于、提供商、开发者开关、危险操作、内存配置、代理部署等端点。
//! 同时包含 `/api/v1/agents/memory/*`（Postgres `app_agent_memory`）。
//!
//! 子模块：
//! - `about` — 关于信息
//! - `vendors` — AI 提供商配置
//! - `dev` — 开发者设置
//! - `danger` — 危险操作
//! - `memory_config` — 内存配置
//! - `agent_deploy` — 代理部署
//! - `agent_memory` — 代理记忆管理

pub mod about;
pub mod agent_deploy;
pub mod agent_memory;
pub mod danger;
pub mod dev;
pub mod memory_config;
pub mod vendors;
