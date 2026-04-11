//! HTTP 工具箱：跨模块 HTTP 辅助功能。
//!
//! 提供 JSON Patch 解析、X-Request-Id 错误注入、速率限制等功能。
//! 子模块：
//! - `json_patch` — JSON Patch 解析
//! - `rate_limit` — 速率限制
//! - `request_id_mw` — 请求 ID 中间件

pub mod json_patch;
pub mod rate_limit;
pub mod request_id_mw;
