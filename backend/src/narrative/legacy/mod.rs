//! 遗留 `/api/novel/*` 读/删除和分页 CRUD 形式的 `POST` 路由（位于 `/api/v1/novels/*` 下）。
//! `id` / `projectId` 指 `app_novel.legacy_id` / `app_project.legacy_id`。

mod dto;
mod extraction;
mod handlers;

pub(super) const MAX_BATCH_DELETE_NOVELS: usize = 500;
pub(super) const MAX_ADD_NOVEL_BATCH: usize = 200;
pub(super) const MAX_GET_NOVEL_LIMIT: i64 = 200;
pub(super) const ADV_LOCK_NOVEL_LEGACY: i64 = 884_422_006;
pub(super) const DEFAULT_GENERATE_EVENTS_CONCURRENCY: usize = 5;
pub(super) const MAX_GENERATE_EVENTS_CONCURRENCY: usize = 20;

use axum::routing::post;
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/novels/get-novel-data",
            post(handlers::post_get_novel_data),
        )
        .route(
            "/api/v1/novels/get-novel-index",
            post(handlers::post_get_novel_index),
        )
        .route(
            "/api/v1/novels/get-novel-event-state",
            post(handlers::post_get_novel_event_state),
        )
        .route("/api/v1/novels/get-novel", post(handlers::post_get_novel))
        .route("/api/v1/novels/add-novel", post(handlers::post_add_novel))
        .route(
            "/api/v1/novels/delete-novel",
            post(handlers::post_delete_novel),
        )
        .route(
            "/api/v1/novels/update-novel",
            post(handlers::post_update_novel),
        )
        .route(
            "/api/v1/novels/batch-delete",
            post(handlers::post_batch_delete_novels),
        )
        .route(
            "/api/v1/novels/events/generate-events",
            post(handlers::post_generate_novel_events),
        )
}

#[cfg(test)]
mod tests;
