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
use crate::http_kit::request_dedupe::{dedupe_platform_copy, RequestDedupeKey};
use crate::metering::llm_usage::record_llm_usage;
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::state::AppState;

use super::copy_validate::adapter_copy_issues_for_inputs;
use super::store::{
    batch_archive_drafts, batch_set_draft_scheduled_at, fetch_draft, fetch_drafts_by_ids,
    insert_publish_job, list_targets, merge_draft_platform_copy,
};
use super::suggest_copy::suggest_platform_copy_fragment;
use super::types::{
    BatchArchiveDraftsBody, BatchArchiveDraftsResponse, BatchOperationFailure,
    BatchPublishDraftsBody, BatchPublishDraftsResponse, BatchScheduleDraftsBody,
    BatchScheduleDraftsResponse, BatchValidateDraftsBody, BatchValidateDraftsResponse,
    BlockedDraftSummary, CreatePublishJobBody, PublishValidateCopyBody,
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
            "/api/v1/projects/{project_id}/publish/drafts/batch-publish",
            post(batch_publish_drafts),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/batch-archive",
            post(batch_archive_publish_drafts),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/batch-validate",
            post(batch_validate_publish_drafts),
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
    let _pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let Some(draft) = fetch_draft(pool, project_id, draft_id).await? else {
        return Err(ApiError::NotFound);
    };
    let targets = list_targets(pool, draft_id).await?;

    // J.6: Deduplicate concurrent generation requests to prevent redundant LLM calls
    let dedupe_key = RequestDedupeKey::suggest_platform_copy(
        uid,
        project_id,
        draft_id,
        body.style_hint.as_deref(),
    );

    // Wrap the generation in deduplication
    let result_json = dedupe_platform_copy(dedupe_key, || async {
        let result = suggest_platform_copy_fragment(
            &state,
            pool,
            &draft,
            &targets,
            body.style_hint.as_deref(),
        )
        .await?;

        // Serialize result for caching
        serde_json::to_value(&result)
            .map_err(|e| ApiError::BadRequest(format!("Failed to serialize result: {}", e)))
    })
    .await?;

    // J.3: Log LLM usage for publish copy generation (both success and failure)
    let model_name = state
        .llm
        .as_ref()
        .map(|cfg| cfg.model.as_str())
        .unwrap_or("fallback");
    let provider = state.llm.as_ref().and_then(|cfg| {
        if cfg.base_url.contains("openai") {
            Some("openai")
        } else if cfg.base_url.contains("anthropic") {
            Some("anthropic")
        } else {
            None
        }
    });

    // Deserialize to get metadata for logging
    if let Ok(res) =
        serde_json::from_value::<super::suggest_copy::PlatformCopyResult>(result_json.clone())
    {
        let meta = serde_json::json!({
            "draft_id": draft_id,
            "project_uuid": project_id,
            "source": res.source,
            "cache_hit": res.cache_hit,
            "platforms_generated": res.platforms_generated,
            "style_hint": body.style_hint,
            "deduplicated": true,
        });

        record_llm_usage(
            pool,
            uid,
            None, // project_id (numeric) - not available in publish domain
            None, // script_id
            None, // job_id
            "publish_copy_generation",
            model_name,
            provider,
            res.usage.as_ref(),
            None, // prompt_chars
            true, // success
            None, // error_message
            res.duration_ms,
            meta,
        )
        .await;
    }

    let result: super::suggest_copy::PlatformCopyResult = serde_json::from_value(result_json)
        .map_err(|e| ApiError::BadRequest(format!("Failed to deserialize result: {}", e)))?;

    if body.apply {
        merge_draft_platform_copy(pool, project_id, draft_id, &result.fragment).await?;
    }
    Ok(Json(SuggestPlatformCopyResponse {
        draft_id,
        platform_copy_fragment: result.fragment,
        source: result.source.to_string(),
    }))
}

/// P8: Batch publish multiple drafts
#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts/batch-publish",
    operation_id = "batchPublishDraftsV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = BatchPublishDraftsBody,
    responses(
        (status = 200, description = "OK", body = BatchPublishDraftsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn batch_publish_drafts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<BatchPublishDraftsBody>,
) -> Result<Json<BatchPublishDraftsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let mut enqueued = 0i64;
    let mut failed = Vec::new();

    for draft_id in &body.draft_ids {
        // Check if draft exists
        match fetch_draft(pool, project_id, *draft_id).await? {
            Some(_) => {
                // Create publish job
                let job_body = CreatePublishJobBody {
                    payload: serde_json::json!({}),
                };
                match insert_publish_job(pool, project_id, *draft_id, uid, &job_body).await {
                    Ok(_) => enqueued += 1,
                    Err(e) => failed.push(BatchOperationFailure {
                        draft_id: *draft_id,
                        reason: format!("{:?}", e),
                    }),
                }
            }
            None => failed.push(BatchOperationFailure {
                draft_id: *draft_id,
                reason: "Draft not found".to_string(),
            }),
        }
    }

    Ok(Json(BatchPublishDraftsResponse { enqueued, failed }))
}

/// P8: Batch archive multiple drafts
#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts/batch-archive",
    operation_id = "batchArchivePublishDraftsV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = BatchArchiveDraftsBody,
    responses(
        (status = 200, description = "OK", body = BatchArchiveDraftsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn batch_archive_publish_drafts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<BatchArchiveDraftsBody>,
) -> Result<Json<BatchArchiveDraftsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let archived = batch_archive_drafts(pool, project_id, &body.draft_ids).await?;
    Ok(Json(BatchArchiveDraftsResponse { archived }))
}

/// P8: Batch validate multiple drafts before operation
#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts/batch-validate",
    operation_id = "batchValidatePublishDraftsV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = BatchValidateDraftsBody,
    responses(
        (status = 200, description = "OK", body = BatchValidateDraftsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn batch_validate_publish_drafts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<BatchValidateDraftsBody>,
) -> Result<Json<BatchValidateDraftsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let drafts = fetch_drafts_by_ids(pool, project_id, &body.draft_ids).await?;
    let mut ready_count = 0i64;
    let mut blocked_drafts = Vec::new();

    for draft in drafts {
        // Fetch targets for this draft
        let targets = list_targets(pool, draft.id).await?;

        // Basic validation: check if draft has required fields
        let mut blocking_reasons = Vec::new();

        if draft.video_asset_key.is_none()
            || draft
                .video_asset_key
                .as_ref()
                .is_none_or(|s| s.trim().is_empty())
        {
            blocking_reasons.push(super::types::PublishPrepareIssue {
                code: "missing_video".to_string(),
                message: "Video asset is required".to_string(),
                platform_id: None,
                severity: "blocking".to_string(),
            });
        }

        if draft.title.trim().is_empty() {
            blocking_reasons.push(super::types::PublishPrepareIssue {
                code: "missing_title".to_string(),
                message: "Title is required".to_string(),
                platform_id: None,
                severity: "blocking".to_string(),
            });
        }

        if targets.is_empty() {
            blocking_reasons.push(super::types::PublishPrepareIssue {
                code: "no_targets".to_string(),
                message: "No publish targets configured".to_string(),
                platform_id: None,
                severity: "blocking".to_string(),
            });
        }

        if blocking_reasons.is_empty() {
            ready_count += 1;
        } else {
            blocked_drafts.push(BlockedDraftSummary {
                draft_id: draft.id,
                title: draft.title.clone(),
                blocking_reasons,
            });
        }
    }

    let blocked_count = blocked_drafts.len() as i64;

    Ok(Json(BatchValidateDraftsResponse {
        ready_count,
        blocked_count,
        blocked_drafts,
    }))
}
