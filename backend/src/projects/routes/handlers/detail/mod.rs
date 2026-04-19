//! 单项目读、统计、PATCH 与删除。

mod delete;
mod get;
mod patch;
mod stats;

pub(crate) use delete::delete_project_by_id;
pub(crate) use get::get_project_by_id;
pub(crate) use patch::patch_project_by_id;
pub(crate) use stats::project_stats_by_id;
