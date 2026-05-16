//! 实验运行与变体快照 HTTP 处理器和数据模型。

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

mod cost_optimization;
mod handlers;
mod types;
mod validation;

#[cfg(test)]
mod tests;

pub use cost_optimization::{
    ArtifactReuse, CostOptimizationConfig, SampleTier, Stage, TokenSavingsEstimate,
};
pub(crate) use handlers::{
    __path_cancel_experiment, __path_compare_ab_jobs, __path_create_experiment,
    __path_get_ab_compare_run, __path_get_experiment, __path_list_ab_compare_runs,
    __path_list_experiments, __path_start_experiment,
};
pub use handlers::{
    cancel_experiment, compare_ab_jobs, create_experiment, estimate_cost, get_ab_compare_run,
    get_experiment, list_ab_compare_runs, list_experiments, start_experiment,
};
pub use types::{
    CreateExperimentBody, CreateVariantBody, ExperimentRun, ExperimentVariant,
    MemoryBudgetSnapshot, ModelRouteSnapshot, ObservationPolicySnapshot, PromptSnapshot,
    SkillSnapshot,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/benchmark/experiments",
            post(handlers::create_experiment).get(handlers::list_experiments),
        )
        .route(
            "/api/v1/benchmark/experiments/{id}",
            get(handlers::get_experiment),
        )
        .route(
            "/api/v1/benchmark/experiments/{id}/start",
            post(handlers::start_experiment),
        )
        .route(
            "/api/v1/benchmark/experiments/{id}/cancel",
            post(handlers::cancel_experiment),
        )
        .route(
            "/api/v1/benchmark/experiments/{id}/cost-estimate",
            get(handlers::estimate_cost),
        )
        .route(
            "/api/v1/benchmark/ab/compare",
            post(handlers::compare_ab_jobs),
        )
        .route(
            "/api/v1/benchmark/ab/runs",
            get(handlers::list_ab_compare_runs),
        )
        .route(
            "/api/v1/benchmark/ab/runs/{id}",
            get(handlers::get_ab_compare_run),
        )
}
