//! REST routes under `/api/v1/jobs` and the in-process poller in [`worker`]（`worker/mod.rs` + `worker/*` 子模块）。

pub mod queue;
pub mod worker;

mod dto;
mod enqueue;
mod handlers;
mod kinds;

// Public API surface for other crates / tests; not all items referenced from this module body.
#[allow(unused_imports)]
pub use dto::{CreateJobBody, JobRow};
pub use enqueue::{enqueue_generation_job, envelope_generation_job_updated};
pub use handlers::JobsOpenApi;
pub use kinds::{
    JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH,
    JOB_KIND_ASSET_POLISH_PROMPT, JOB_KIND_FLUTTER_PROBE, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST,
    JOB_KIND_VIDEO_EXPORT, JOB_KIND_VIDEO_GENERATE, JOB_KIND_VOICEOVER_GENERATE,
};

use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    handlers::router()
}

#[cfg(test)]
mod tests;
