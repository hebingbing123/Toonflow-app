//! Postgres 支持的项目 REST 和遗留 `/api/v1/project/*` 路由。
//!
//! 子模块：
//! - `legacy` — 遗留项目接口
//! - `routes` — 项目 REST 路由

pub mod legacy;
pub mod routes;

pub use routes::ProjectRow;
