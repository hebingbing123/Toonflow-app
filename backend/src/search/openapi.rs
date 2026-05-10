//! OpenAPI fragment for search routes (`/api/v1/search/*`).

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::search::routes::search_handler,
        crate::search::routes::get_search_history,
        crate::search::routes::delete_search_history,
    ),
    components(schemas(
        crate::search::models::SearchQuery,
        crate::search::models::SearchResponse,
        crate::search::models::SearchResult,
        crate::search::models::ResultType,
        crate::search::models::HistoryResponse,
        crate::search::models::HistoryEntry,
    )),
    tags(
        (name = "search", description = "全局搜索：跨项目、剧本、资产、小说章节与大纲事件的全文搜索")
    )
)]
pub struct SearchOpenApi;
