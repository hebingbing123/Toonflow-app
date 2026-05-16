//! 小说事件：CRUD、章节关联与章节事件抽取。

mod dto;
mod extraction;
mod handlers;
mod query;

pub(crate) const DEFAULT_GENERATE_EVENTS_CONCURRENCY: usize = 5;
pub(crate) const MAX_GENERATE_EVENTS_CONCURRENCY: usize = 20;
pub(crate) const MAX_EVENT_BATCH_DELETE: usize = 500;
pub(crate) const MAX_EVENT_LIST_LIMIT: i64 = 200;

/// `pg_advisory_xact_lock` key for allocating globally unique `app_novel_event.numeric_id`.
pub(crate) const ADV_LOCK_NOVEL_EVENT_NUMERIC: i64 = 884_422_007;

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
            "/api/v1/projects/{project_id}/novel-events/generate-events",
            post(handlers::post_generate_novel_events_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/novel-events/{event_numeric_id}",
            delete(handlers::delete_novel_event_for_project)
                .patch(handlers::update_novel_event_for_project),
        )
}

#[cfg(test)]
mod property_tests;

#[cfg(test)]
mod tests;
