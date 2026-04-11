//! Novel events (legacy **`o_event`** / **`o_eventChapter`**): CRUD and chapter associations.

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
        // RESTful routes
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novel-events",
            get(handlers::list_novel_events).post(handlers::create_novel_event),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novel-events/{event_legacy_id}",
            delete(handlers::delete_novel_event).patch(handlers::update_novel_event),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novel-events/batch-delete",
            post(handlers::batch_delete_novel_events),
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
