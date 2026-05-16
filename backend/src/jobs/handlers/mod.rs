//! 任务 REST 路由（`GET /api/v1/jobs/*`）。
//!
//! 任务列表、详情、取消和状态查询处理器。

mod common;
mod listing;
mod mutate;
mod queue_stats;
mod summaries;

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

use listing::{get_job, get_job_file, get_job_task_detail_compat, list_jobs, list_jobs_page};
use mutate::{cancel_job, create_job, retry_job};
use queue_stats::get_job_queue_stats;
use summaries::{list_job_kind_summaries, list_job_kinds, list_job_status_summaries};

#[allow(unused_imports)]
pub(crate) use common::{
    idempotency_key_header, list_jobs_limit_offset, normalize_job_list_status_filter,
    trim_query_opt,
};

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/jobs/queue/stats", get(get_job_queue_stats))
        .route("/api/v1/jobs/page", get(list_jobs_page))
        .route(
            "/api/v1/jobs/task-detail/{task_id}",
            get(get_job_task_detail_compat),
        )
        .route("/api/v1/jobs/kinds/summary", get(list_job_kind_summaries))
        .route("/api/v1/jobs/kinds", get(list_job_kinds))
        .route(
            "/api/v1/jobs/status/summary",
            get(list_job_status_summaries),
        )
        .route("/api/v1/jobs", get(list_jobs).post(create_job))
        .route("/api/v1/jobs/{id}", get(get_job))
        .route("/api/v1/jobs/{id}/file", get(get_job_file))
        .route("/api/v1/jobs/{id}/cancel", post(cancel_job))
        .route("/api/v1/jobs/{id}/retry", post(retry_job))
}

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(
        queue_stats::get_job_queue_stats,
        listing::list_jobs_page,
        listing::get_job_task_detail_compat,
        summaries::list_job_kind_summaries,
        summaries::list_job_kinds,
        summaries::list_job_status_summaries,
        listing::list_jobs,
        mutate::create_job,
        listing::get_job,
        listing::get_job_file,
        mutate::cancel_job,
        mutate::retry_job,
    ),
    components(schemas(crate::error::ErrorBody, queue_stats::JobQueueStatsResponse)),
    tags((name = "jobs", description = "Generation jobs"))
)]
pub struct JobsOpenApi;
