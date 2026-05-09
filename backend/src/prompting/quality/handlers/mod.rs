//! 质量审查 HTTP 处理器。

pub(crate) mod aggregates;
pub(crate) mod bad_case_frequency;
pub(crate) mod bad_case_stats;
pub(crate) mod create;
mod get;
mod list;
pub(crate) mod skill_version_comparison;

pub(crate) use aggregates::{
    __path_get_dashboard, __path_get_scope_insights, __path_get_stage_grade_distribution,
    __path_get_stage_pass_rate, __path_get_stats, __path_get_token_efficiency,
    __path_get_token_efficiency_samples, __path_post_dashboard_refresh, get_dashboard,
    get_scope_insights, get_stage_grade_distribution, get_stage_pass_rate, get_stats,
    get_token_efficiency, get_token_efficiency_samples, post_dashboard_refresh,
};
pub(crate) use bad_case_frequency::{__path_get_bad_case_frequency, get_bad_case_frequency};
pub(crate) use bad_case_stats::{__path_get_bad_case_stats, get_bad_case_stats};
pub(crate) use create::{__path_create_review, create_review};
pub(crate) use get::{__path_get_review, get_review};
pub(crate) use list::{__path_list_reviews, list_reviews};
pub(crate) use skill_version_comparison::{
    __path_get_skill_version_comparison, get_skill_version_comparison,
};
