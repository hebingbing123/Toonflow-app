//! OpenAPI fragment: `GET/POST/PATCH /api/v1/projects/{project_id}/publish/*`.

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::publish::handlers::publish_platform_matrix,
        crate::publish::handlers::list_publish_profiles,
        crate::publish::handlers::create_publish_profile,
        crate::publish::handlers::get_publish_profile,
        crate::publish::handlers::patch_publish_profile,
        crate::publish::handlers::delete_publish_profile,
        crate::publish::handlers::list_publish_drafts,
        crate::publish::handlers::create_publish_draft,
        crate::publish::handlers::get_publish_draft,
        crate::publish::handlers::patch_publish_draft,
        crate::publish::handlers::delete_publish_draft_handler,
        crate::publish::handlers::list_publish_targets,
        crate::publish::handlers::upsert_publish_targets,
        crate::publish::handlers::publish_prepare_check,
        crate::publish::handlers::create_publish_job,
        crate::publish::handlers::list_publish_jobs,
        crate::publish::handlers::list_publish_audit,
        crate::publish::handlers::cancel_publish_job,
        crate::publish::handlers::retry_publish_job,
        crate::publish::handlers::confirm_publish_job_semi_auto,
        crate::publish::handlers_f::publish_validate_copy,
        crate::publish::handlers_f::batch_schedule_publish_drafts,
        crate::publish::handlers_f::suggest_publish_platform_copy,
    ),
    components(schemas(
        crate::publish::types::PublishProfileResponse,
        crate::publish::types::CreatePublishProfileBody,
        crate::publish::types::PatchPublishProfileBody,
        crate::publish::types::PublishDraftResponse,
        crate::publish::types::ListPublishDraftsQuery,
        crate::publish::types::CreatePublishDraftBody,
        crate::publish::types::PatchPublishDraftBody,
        crate::publish::types::PublishTargetResponse,
        crate::publish::types::UpsertPublishTargetsBody,
        crate::publish::types::PublishTargetInput,
        crate::publish::types::PublishJobResponse,
        crate::publish::types::CreatePublishJobBody,
        crate::publish::types::ListPublishAuditQuery,
        crate::publish::types::PublishAttemptAuditResponse,
        crate::publish::types::PublishPrepareIssue,
        crate::publish::types::PublishPrepareCheckResponse,
        crate::publish::types::PublishPlatformCapabilityRow,
        crate::publish::types::PublishPlatformMatrixResponse,
        crate::publish::types::PublishValidateCopyBody,
        crate::publish::types::PublishValidateCopyResponse,
        crate::publish::types::SuggestPlatformCopyBody,
        crate::publish::types::SuggestPlatformCopyResponse,
        crate::publish::types::BatchScheduleDraftsBody,
        crate::publish::types::BatchScheduleDraftsResponse,
    )),
    tags(
        (name = "publish", description = "Short-video publish drafts, targets, jobs (Wave 4)")
    )
)]
pub struct PublishOpenApi;
