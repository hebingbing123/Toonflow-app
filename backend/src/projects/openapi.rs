//! OpenAPI fragment for projects routes (`/api/v1/projects/*`).

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::projects::routes::handlers::create_list::list::list_projects,
        crate::projects::routes::handlers::create_list::create::create_project,
        crate::projects::routes::handlers::create_list::summary::projects_summary,
        crate::projects::routes::handlers::detail::get::get_project_by_id,
        crate::projects::routes::handlers::detail::patch::patch_project_by_id,
        crate::projects::routes::handlers::detail::delete::delete_project_by_id,
        crate::projects::routes::handlers::detail::style_config::patch_style_config,
        crate::projects::routes::handlers::detail::stats::project_stats_by_id,
        crate::projects::routes::handlers::detail::short_video_readiness::project_short_video_readiness_by_id,
        crate::projects::routes::handlers::detail::short_video_assembly::project_short_video_assembly_by_id,
        crate::projects::routes::handlers::detail::production_overview::project_production_overview_by_id,
        crate::projects::routes::handlers::detail::assets_overview::project_assets_overview_by_id,
    ),
    components(schemas(
        crate::projects::routes::types::ProjectRow,
        crate::projects::routes::types::ScriptBrief,
        crate::projects::routes::types::ProjectDetailResponse,
        crate::projects::routes::types::ProjectStatsResponse,
        crate::projects::routes::types::StoryboardShortVideoReadiness,
        crate::projects::routes::types::ShortVideoReadinessReasonRollup,
        crate::projects::routes::types::ShortVideoReadinessRollup,
        crate::projects::routes::types::ProjectShortVideoReadinessResponse,
        crate::projects::routes::types::ProjectProductionOverviewResponse,
        crate::projects::routes::types::AssetsOverviewCandidateCounts,
        crate::projects::routes::types::AssetsOverviewItem,
        crate::projects::routes::types::AssetsOverviewTypeGroup,
        crate::projects::routes::types::ProjectAssetsOverviewResponse,
        crate::projects::routes::types::ProjectShortVideoAssemblyResponse,
        crate::projects::routes::types::ShortVideoAssemblyProjectDefaults,
        crate::projects::routes::types::ShortVideoAssemblyScriptGroup,
        crate::projects::routes::types::ShortVideoAssemblyShot,
        crate::projects::routes::types::ProjectsSummaryResponse,
        crate::projects::routes::types::PatchProjectBody,
        crate::projects::routes::types::PatchStyleConfigBody,
        crate::projects::routes::types::CreateProjectBody,
    )),
    tags(
        (name = "projects", description = "Project CRUD and short video configuration")
    )
)]
pub struct ProjectsOpenApi;
