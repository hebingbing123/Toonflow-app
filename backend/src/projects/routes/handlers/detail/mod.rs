//! 单项目读、统计、PATCH 与删除。

pub(crate) mod assets_overview;
pub(crate) mod delete;
pub(crate) mod get;
pub(crate) mod patch;
pub(crate) mod production_overview;
pub(crate) mod short_video_readiness;
pub(crate) mod stats;
pub(crate) mod style_config;

pub(crate) use assets_overview::project_assets_overview_by_id;
pub(crate) use delete::delete_project_by_id;
pub(crate) use get::get_project_by_id;
pub(crate) use patch::patch_project_by_id;
pub(crate) use production_overview::project_production_overview_by_id;
pub(crate) use short_video_readiness::project_short_video_readiness_by_id;
pub(crate) use stats::project_stats_by_id;
pub(crate) use style_config::patch_style_config;
