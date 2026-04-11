//! Project-scoped **`app_novel`** REST (legacy **`o_novel`** index/list/get/update/delete subset).

mod dto;
mod handlers;

// Stable paths `crate::narrative::novels::{NovelRow, …}` (matches pre-split public API).
#[allow(unused_imports)]
pub use dto::{CreateNovelBody, ListNovelsQuery, ListNovelsResponse, NovelRow, PatchNovelBody};

pub(super) const ADV_LOCK_NOVEL_LEGACY: i64 = 884_422_006;
pub(super) const MAX_NOVEL_LIST_LIMIT: i64 = 200;

use axum::routing::get;
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novels",
            get(handlers::list_novels).post(handlers::create_novel),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/novels/{novel_legacy_id}",
            get(handlers::get_novel_by_legacy)
                .patch(handlers::patch_novel_by_legacy)
                .delete(handlers::delete_novel_by_legacy),
        )
}

#[cfg(test)]
mod tests;
