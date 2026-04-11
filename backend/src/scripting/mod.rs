//! 脚本模块：HTTP 路由、遗留脚本 API、脚本代理和资产提取。
//!
//! 子模块：
//! - `scripts` — 脚本 CRUD
//! - `agent` — 脚本代理
//! - `asset_extract` — 资产提取
//! - `legacy` — 遗留 HTTP 端点

pub mod agent;
pub mod asset_extract;
pub mod legacy;
pub mod scripts;
