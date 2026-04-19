//! 分页项目资产列表（`GET …/assets`）。
//!
//! 支持按类型、名称过滤的分页查询。

mod filtered;
mod handler;
mod inner;

pub(crate) use handler::list_project_assets_for_project;
