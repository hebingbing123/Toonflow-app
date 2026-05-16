//! 放行门与有限灰度决策。

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

mod handlers;
mod tests;
mod types;

pub(crate) use handlers::{
    __path_decide_promotion_gate, __path_get_benchmark_trends, __path_get_promotion_gate,
};
pub use types::{
    BenchmarkTrendPoint, BenchmarkTrendsResponse, GateDecisionEnvelope, GateDecisionRecord,
    GateVariantAssessment, SubmitGateDecisionBody,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/benchmark/experiments/{id}/gate",
            get(handlers::get_promotion_gate),
        )
        .route(
            "/api/v1/benchmark/experiments/{id}/gate/decide",
            post(handlers::decide_promotion_gate),
        )
        .route(
            "/api/v1/benchmark/trends",
            get(handlers::get_benchmark_trends),
        )
}
