//! 人工复核队列 HTTP 处理器和数据模型。

use axum::{routing::post, Router};

use crate::state::AppState;

mod handlers;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_create_review_queue_item, __path_get_review_queue, __path_skip_review,
    __path_submit_review,
};
pub use types::{
    CreateReviewQueueBody, GetReviewQueueQuery, ReviewQueueItem, SkipReviewBody, SubmitReviewBody,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/benchmark/review-queue",
            post(handlers::create_review_queue_item).get(handlers::get_review_queue),
        )
        .route(
            "/api/v1/benchmark/review-queue/{id}/submit",
            post(handlers::submit_review),
        )
        .route(
            "/api/v1/benchmark/review-queue/{id}/skip",
            post(handlers::skip_review),
        )
}
