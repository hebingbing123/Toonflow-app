//! 小说事件（遗留 `o_event` / `o_eventChapter`）：CRUD 和章节关联。

mod dto;
mod handlers;
mod query;

pub(crate) const MAX_EVENT_BATCH_DELETE: usize = 500;
pub(crate) const MAX_EVENT_LIST_LIMIT: i64 = 200;

use axum::routing::{delete, get, post};
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/{project_id}/novel-events",
            get(handlers::list_novel_events_for_project)
                .post(handlers::create_novel_event_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/novel-events/batch-delete",
            post(handlers::batch_delete_novel_events_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/novel-events/{event_legacy_id}",
            delete(handlers::delete_novel_event_for_project)
                .patch(handlers::update_novel_event_for_project),
        )
        // Legacy POST routes matching old API
        .route(
            "/api/v1/novels/events/get-events",
            post(handlers::post_get_events),
        )
        .route(
            "/api/v1/novels/events/batch-delete",
            post(handlers::post_batch_delete_events),
        )
}

#[cfg(test)]
mod tests;
