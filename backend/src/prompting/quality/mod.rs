//! 提示词质量审查模块。
//!
//! 质量规则 CRUD 和提示词质量检查处理器。

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

mod feedback;
mod feedback_generic;
mod feedback_memory;
mod feedback_video;
mod handlers;
pub mod issue_type;
pub mod next_action;
mod types;
mod validate;

#[cfg(test)]
mod next_action_tests;
#[cfg(test)]
mod tests;

pub use types::{
    BadCaseFrequencyItem, CreateQualityReviewBody, ListQualityReviewsQuery, QualityReview,
    QualityScopeInsightResponse, QualityStatsResponse, QualityTokenEfficiencyResponse,
    QualityTokenEfficiencySample, SkillVersionComparisonItem, StageGradeDistributionItem,
    StagePassRateItem,
};

pub use next_action::NextAction;

// Handlers 与 utoipa `__path_*` 由 `openapi.rs` 的 `paths(...)` 引用；本模块内仅装配路由。
#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_create_review, __path_get_bad_case_frequency, __path_get_bad_case_stats,
    __path_get_review, __path_get_scope_insights, __path_get_skill_version_comparison,
    __path_get_stage_grade_distribution, __path_get_stage_pass_rate, __path_get_stats,
    __path_get_token_efficiency, __path_get_token_efficiency_samples, __path_list_reviews,
    create_review, get_bad_case_frequency, get_bad_case_stats, get_review, get_scope_insights,
    get_skill_version_comparison, get_stage_grade_distribution, get_stage_pass_rate, get_stats,
    get_token_efficiency, get_token_efficiency_samples, list_reviews,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/quality/reviews",
            post(handlers::create_review).get(handlers::list_reviews),
        )
        .route("/api/v1/quality/reviews/{id}", get(handlers::get_review))
        .route("/api/v1/quality/stats", get(handlers::get_stats))
        .route(
            "/api/v1/quality/scope-insights",
            get(handlers::get_scope_insights),
        )
        .route(
            "/api/v1/quality/token-efficiency",
            get(handlers::get_token_efficiency),
        )
        .route(
            "/api/v1/quality/token-efficiency/samples",
            get(handlers::get_token_efficiency_samples),
        )
        .route(
            "/api/v1/quality/stage-pass-rate",
            get(handlers::get_stage_pass_rate),
        )
        .route(
            "/api/v1/quality/stage-grade-distribution",
            get(handlers::get_stage_grade_distribution),
        )
        .route(
            "/api/v1/quality/bad-case-frequency",
            get(handlers::get_bad_case_frequency),
        )
        .route(
            "/api/v1/quality/bad-case-stats",
            get(handlers::get_bad_case_stats),
        )
        .route(
            "/api/v1/quality/skill-version-comparison",
            get(handlers::get_skill_version_comparison),
        )
}
