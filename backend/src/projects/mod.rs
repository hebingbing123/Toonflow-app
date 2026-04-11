//! 项目模块：PostgreSQL 支持的项目 REST 和遗留 `/api/v1/project/*` 路由。
//!
//! 子模块：
//! - `routes` — 项目 CRUD 路由
//! - `legacy` — 遗留项目 HTTP 端点

pub mod legacy;
pub mod routes;

pub use routes::ProjectRow;
