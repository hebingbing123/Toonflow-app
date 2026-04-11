//! 项目范围的 `app_novel` REST（遗留 `o_novel` 索引/列表/获取/更新/删除子集）。

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
            "/api/v1/projects/{project_id}/novels",
            get(handlers::list_novels_for_project).post(handlers::create_novel_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/novels/{novel_numeric_id}",
            get(handlers::get_novel_for_project)
                .patch(handlers::patch_novel_for_project)
                .delete(handlers::delete_novel_for_project),
        )
}

#[cfg(test)]
mod tests;
