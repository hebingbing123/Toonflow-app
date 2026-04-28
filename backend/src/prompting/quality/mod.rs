//! 提示词质量审查模块。
//!
//! 质量规则 CRUD 和提示词质量检查处理器。

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

mod feedback;
mod handlers;
mod types;
mod validate;

#[cfg(test)]
mod tests;

pub use types::{
    CreateQualityReviewBody, ListQualityReviewsQuery, QualityReview, QualityStatsResponse,
    StagePassRateItem,
};

// Handlers 与 utoipa `__path_*` 由 `openapi.rs` 的 `paths(...)` 引用；本模块内仅装配路由。
#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_create_review, __path_get_review, __path_get_stage_pass_rate, __path_get_stats,
    __path_list_reviews, create_review, get_review, get_stage_pass_rate, get_stats, list_reviews,
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
            "/api/v1/quality/stage-pass-rate",
            get(handlers::get_stage_pass_rate),
        )
}
