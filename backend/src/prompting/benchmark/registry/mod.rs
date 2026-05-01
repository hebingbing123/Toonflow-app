//! 基线样本注册表 HTTP 处理器和数据模型。

use axum::{
    routing::{patch, post},
    Router,
};

use crate::state::AppState;

mod handlers;
mod types;

#[cfg(test)]
mod tests;

pub(crate) use handlers::{
    __path_create_benchmark_case, __path_list_benchmark_cases, __path_promote_from_quality_review,
    __path_update_benchmark_case,
};
pub use types::{
    BenchmarkCase, CreateBenchmarkCaseBody, ListBenchmarkCasesQuery, PromoteFromQualityReviewBody,
    UpdateBenchmarkCaseBody,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/benchmark/cases",
            post(handlers::create_benchmark_case).get(handlers::list_benchmark_cases),
        )
        .route(
            "/api/v1/benchmark/cases/{id}",
            patch(handlers::update_benchmark_case),
        )
        .route(
            "/api/v1/benchmark/cases/promote-from-review",
            post(handlers::promote_from_quality_review),
        )
}
