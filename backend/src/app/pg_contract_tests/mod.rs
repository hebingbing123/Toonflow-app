//! PostgreSQL 契约测试（真实数据库）。
//!
//! 端到端测试覆盖核心业务场景：资产、项目、计费、叙事、制作工作台。
//!
//! 测试需要 Postgres 连接；使用临时数据库并回滚。

mod common;
pub(crate) use common::*;

mod assets_suite;
mod business_suite;
mod content_suite;
mod e2e_regression_suite;
mod narrative_suite;
mod ops_suite;
mod production_suite;
mod projects_create_stats_roundtrip;
mod projects_numeric_crud_roundtrip;
mod projects_partial_patch_roundtrip;
