//! 项目范围的 `app_novel` REST（遗留 `o_novel` 索引/列表/获取/更新/删除子集）。

pub(crate) mod crawl_auth;
mod dto;
pub(crate) mod handlers;
mod openapi;

// Stable paths `crate::narrative::novels::{NovelRow, …}` (matches pre-split public API).
#[allow(unused_imports)]
pub use dto::{
    CreateNovelBody, ListNovelsQuery, ListNovelsResponse, NovelCrawlPreviewBody,
    NovelCrawlPreviewResponse, NovelRow, PatchNovelBody,
};
pub use openapi::NovelsHttpOpenApi;

pub(super) const ADV_LOCK_NOVEL_NUMERIC: i64 = 884_422_006;
pub(super) const MAX_NOVEL_LIST_LIMIT: i64 = 200;

use axum::routing::{get, post};
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/{project_id}/novels/crawl-auth",
            get(handlers::get_novel_crawl_auth).put(handlers::put_novel_crawl_auth),
        )
        .route(
            "/api/v1/projects/{project_id}/novels/crawl-preview",
            post(handlers::post_novel_crawl_preview),
        )
        .route(
            "/api/v1/projects/{project_id}/novels/crawl-import",
            post(handlers::post_novel_crawl_import),
        )
        .route(
            "/api/v1/projects/{project_id}/novels/crawl-import-batch",
            post(handlers::post_novel_crawl_import_batch),
        )
        .route(
            "/api/v1/projects/{project_id}/novels/crawl-schedules",
            get(handlers::list_novel_crawl_schedules)
                .post(handlers::post_novel_crawl_schedule_create),
        )
        .route(
            "/api/v1/projects/{project_id}/novels/crawl-observability",
            get(handlers::get_novel_crawl_observability),
        )
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
