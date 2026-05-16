//! OpenAPI fragment for search routes (`/api/v1/search/*`).

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::search::routes::search_handler,
        crate::search::routes::get_search_history,
        crate::search::routes::delete_search_history,
        crate::search::saved_views::get_search_saved_views,
        crate::search::saved_views::put_search_saved_views,
    ),
    components(schemas(
        crate::search::models::SearchQuery,
        crate::search::models::SearchResponse,
        crate::search::models::SearchResult,
        crate::search::models::ResultType,
        crate::search::models::HistoryResponse,
        crate::search::models::HistoryEntry,
        crate::search::models::SearchSavedViewItem,
        crate::search::models::SearchSavedViewsResponse,
        crate::search::models::SearchSavedViewsPutBody,
    )),
    tags(
        (name = "search", description = "全局搜索：跨项目、剧本、资产、小说章节与大纲事件的全文搜索")
    )
)]
pub struct SearchOpenApi;
