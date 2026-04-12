//! WebSocket 协议栈（`GET /api/v1/ws`）：升级 → 连接循环 → 认证 → 调度 → 工具/代理/聊天/会话处理器。

pub mod agent;
pub mod auth;
pub mod channel;
pub mod chat;
pub mod connection;
pub mod dispatch;
pub mod openapi;
pub mod outbound;
pub mod session;
pub mod tool;
pub mod upgrade;

pub use openapi::WsUpgradeOpenApi;
