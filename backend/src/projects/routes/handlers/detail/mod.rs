//! 单项目读、统计、PATCH 与删除。

pub(crate) mod assembly_query;
pub(crate) mod assets_overview;
pub(crate) mod audit;
pub(crate) mod delete;
pub(crate) mod get;
pub(crate) mod home;
pub(crate) mod members;
pub(crate) mod overview;
pub(crate) mod patch;
pub(crate) mod production_overview;
pub(crate) mod short_video_assembly;
pub(crate) mod short_video_export;
pub(crate) mod short_video_export_check;
pub(crate) mod short_video_pre_assembly;
pub(crate) mod short_video_readiness;
pub(crate) mod short_video_timeline;
pub(crate) mod stats;
pub(crate) mod style_config;

pub(crate) use assets_overview::project_assets_overview_by_id;
pub(crate) use audit::list_project_audit;
pub(crate) use delete::delete_project_by_id;
pub(crate) use get::get_project_by_id;
pub(crate) use home::project_home_by_id;
pub(crate) use members::{
    create_project_member, delete_project_member, list_project_members, patch_project_member,
};
pub(crate) use overview::project_overview_by_id;
pub(crate) use patch::patch_project_by_id;
pub(crate) use production_overview::project_production_overview_by_id;
pub(crate) use short_video_assembly::project_short_video_assembly_by_id;
pub(crate) use short_video_export::project_short_video_export_by_id;
pub(crate) use short_video_export_check::project_short_video_export_check_by_id;
pub(crate) use short_video_pre_assembly::project_short_video_pre_assembly_by_id;
pub(crate) use short_video_readiness::project_short_video_readiness_by_id;
pub(crate) use short_video_timeline::{
    project_short_video_timeline_apply_template, project_short_video_timeline_by_id,
    project_short_video_timeline_preview, project_short_video_timeline_put,
    project_short_video_timeline_reorder, project_short_video_timeline_restore,
    project_short_video_timeline_revisions,
};
pub(crate) use stats::project_stats_by_id;
pub(crate) use style_config::patch_style_config;
