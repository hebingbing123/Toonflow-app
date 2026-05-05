//! 单项目读、统计、PATCH 与删除。

pub(crate) mod delete;
pub(crate) mod get;
pub(crate) mod patch;
pub(crate) mod stats;
pub(crate) mod style_config;

pub(crate) use delete::delete_project_by_id;
pub(crate) use get::get_project_by_id;
pub(crate) use patch::patch_project_by_id;
pub(crate) use stats::project_stats_by_id;
pub(crate) use style_config::patch_style_config;
