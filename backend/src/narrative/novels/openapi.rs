//! OpenAPI fragment for server-assisted novel intake routes.

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::narrative::novels::handlers::crawl_preview::post_novel_crawl_preview,
        crate::narrative::novels::handlers::crawl_preview::post_novel_crawl_import,
        crate::narrative::novels::handlers::crawl_preview::post_novel_crawl_import_batch,
        crate::narrative::novels::handlers::crawl_schedule::post_novel_crawl_schedule_create,
        crate::narrative::novels::handlers::crawl_schedule::list_novel_crawl_schedules,
    ),
    components(schemas(
        crate::narrative::novels::dto::NovelCrawlPreviewBody,
        crate::narrative::novels::dto::NovelCrawlPreviewResponse,
        crate::narrative::novels::dto::NovelCrawlImportBody,
        crate::narrative::novels::dto::NovelCrawlImportResponse,
        crate::narrative::novels::dto::NovelCrawlImportBatchBody,
        crate::narrative::novels::dto::NovelCrawlImportBatchItem,
        crate::narrative::novels::dto::NovelCrawlImportBatchResponse,
        crate::narrative::novels::handlers::crawl_schedule::NovelCrawlScheduleCreateBody,
        crate::narrative::novels::handlers::crawl_schedule::NovelCrawlScheduleRow,
    )),
    tags(
        (name = "novels", description = "Novel chapters per project (`app_novel`)")
    )
)]
pub struct NovelsHttpOpenApi;
