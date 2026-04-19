//! 使用计量（`app_usage_event`，§12.3）：记录服务器端结果并公开每个用户的计数。

use axum::routing::get;
use axum::Router;

use crate::state::AppState;

mod record;
mod summary;

#[cfg(test)]
mod tests;

pub use record::{record_generation_job_created, record_generation_job_succeeded};

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(summary::usage_summary),
    components(schemas(summary::UsageSummaryResponse, crate::error::ErrorBody)),
    tags((name = "usage", description = "Per-user usage and quota hints"))
)]
pub struct MeteringOpenApi;

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/usage/summary", get(summary::usage_summary))
}
