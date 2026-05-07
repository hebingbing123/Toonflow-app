//! OpenAPI fragment for server-assisted novel intake routes.

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::narrative::novels::handlers::crawl_preview::post_novel_crawl_preview,
    ),
    components(schemas(
        crate::narrative::novels::dto::NovelCrawlPreviewBody,
        crate::narrative::novels::dto::NovelCrawlPreviewResponse,
    )),
    tags(
        (name = "novels", description = "Novel chapters per project (`app_novel`)")
    )
)]
pub struct NovelsHttpOpenApi;
