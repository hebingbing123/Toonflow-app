//! Wave β (**F**) — validate-copy, suggest-platform-copy, batch-schedule.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::post,
    Json, Router,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::access::require_project_owned;
use super::copy_validate::adapter_copy_issues_for_inputs;
use super::store::{
    batch_set_draft_scheduled_at, fetch_draft, list_targets, merge_draft_platform_copy,
};
use super::suggest_copy::suggest_platform_copy_fragment;
use super::types::{
    BatchScheduleDraftsBody, BatchScheduleDraftsResponse, PublishValidateCopyBody,
    PublishValidateCopyResponse, SuggestPlatformCopyBody, SuggestPlatformCopyResponse,
};
use super::validation::prepare_issues_target_inputs_only;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/{project_id}/publish/validate-copy",
            post(publish_validate_copy),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/batch-schedule",
            post(batch_schedule_publish_drafts),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/suggest-platform-copy",
            post(suggest_publish_platform_copy),
        )
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/validate-copy",
    operation_id = "validatePublishCopyV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = PublishValidateCopyBody,
    responses(
        (status = 200, description = "OK", body = PublishValidateCopyResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn publish_validate_copy(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<PublishValidateCopyBody>,
) -> Result<Json<PublishValidateCopyResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;

    let mut issues = prepare_issues_target_inputs_only(&body.targets);
    issues.extend(adapter_copy_issues_for_inputs(
        &body.platform_copy,
        &body.targets,
    ));
    let blocking = issues.iter().any(|i| i.severity == "blocking");
    Ok(Json(PublishValidateCopyResponse {
        ok: !blocking,
        issues,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts/batch-schedule",
    operation_id = "batchSchedulePublishDraftsV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = BatchScheduleDraftsBody,
    responses(
        (status = 200, description = "OK", body = BatchScheduleDraftsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn batch_schedule_publish_drafts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<BatchScheduleDraftsBody>,
) -> Result<Json<BatchScheduleDraftsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;

    let n =
        batch_set_draft_scheduled_at(pool, project_id, &body.draft_ids, body.scheduled_at).await?;
    Ok(Json(BatchScheduleDraftsResponse { updated: n }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/suggest-platform-copy",
    operation_id = "suggestPublishPlatformCopyV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    request_body = SuggestPlatformCopyBody,
    responses(
        (status = 200, description = "OK", body = SuggestPlatformCopyResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn suggest_publish_platform_copy(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<SuggestPlatformCopyBody>,
) -> Result<Json<SuggestPlatformCopyResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;

    let Some(draft) = fetch_draft(pool, project_id, draft_id).await? else {
        return Err(ApiError::NotFound);
    };
    let targets = list_targets(pool, draft_id).await?;
    let (fragment, source) =
        suggest_platform_copy_fragment(&state, &draft, &targets, body.style_hint.as_deref())
            .await?;
    if body.apply {
        merge_draft_platform_copy(pool, project_id, draft_id, &fragment).await?;
    }
    Ok(Json(SuggestPlatformCopyResponse {
        draft_id,
        platform_copy_fragment: fragment,
        source: source.to_string(),
    }))
}
