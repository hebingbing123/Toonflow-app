//! HTTP handlers for `/api/v1/projects/{project_id}/publish/*` (**E9**).

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::request_dedupe::{dedupe_publish_overview, RequestDedupeKey};
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::store::{
    fetch_draft, list_attempt_audit, list_drafts, list_jobs, list_low_performance_alerts,
    list_targets, ListAttemptAuditFilter,
};
use super::types::{PublishOverviewQuery, PublishOverviewResponse, PublishPrepareCheckResponse};
use super::validation::prepare_check_for_draft;
use super::{attempt_audit_from_row, draft_from_row, job_from_row, performance_alert_from_row};

pub(super) mod audit;
pub(super) mod draft;
pub(super) mod job;
pub(super) mod profile;
pub(super) mod target;

// Re-export all handler functions
pub(crate) use audit::{
    list_publish_audit, list_publish_performance_alerts, process_performance_alerts,
    publish_platform_matrix,
};
pub(crate) use draft::{
    create_publish_draft, delete_publish_draft_handler, get_publish_draft, list_publish_drafts,
    patch_publish_draft,
};
pub(crate) use job::{
    cancel_publish_job, confirm_publish_job_semi_auto, create_publish_job, list_publish_jobs,
    publish_prepare_check, retry_publish_job,
};
pub(crate) use profile::{
    create_publish_profile, delete_publish_profile, get_publish_profile, list_publish_profiles,
    patch_publish_profile,
};
pub(crate) use target::{list_publish_targets, upsert_publish_targets};

// Re-export utoipa-generated types for OpenAPI
pub(crate) use audit::{
    __path_list_publish_audit, __path_list_publish_performance_alerts,
    __path_process_performance_alerts, __path_publish_platform_matrix,
};
pub(crate) use draft::{
    __path_create_publish_draft, __path_delete_publish_draft_handler, __path_get_publish_draft,
    __path_list_publish_drafts, __path_patch_publish_draft,
};
pub(crate) use job::{
    __path_cancel_publish_job, __path_confirm_publish_job_semi_auto, __path_create_publish_job,
    __path_list_publish_jobs, __path_publish_prepare_check, __path_retry_publish_job,
};
pub(crate) use profile::{
    __path_create_publish_profile, __path_delete_publish_profile, __path_get_publish_profile,
    __path_list_publish_profiles, __path_patch_publish_profile,
};
pub(crate) use target::{__path_list_publish_targets, __path_upsert_publish_targets};

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/{project_id}/publish/overview",
            get(publish_overview),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/platform-matrix",
            get(publish_platform_matrix),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/profiles",
            get(list_publish_profiles).post(create_publish_profile),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/profiles/{profile_id}",
            get(get_publish_profile)
                .patch(patch_publish_profile)
                .delete(delete_publish_profile),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts",
            get(list_publish_drafts).post(create_publish_draft),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/{draft_id}",
            get(get_publish_draft)
                .patch(patch_publish_draft)
                .delete(delete_publish_draft_handler),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/targets",
            get(list_publish_targets).post(upsert_publish_targets),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/prepare-check",
            get(publish_prepare_check),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/jobs",
            post(create_publish_job),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/jobs",
            get(list_publish_jobs),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/audit",
            get(list_publish_audit),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/performance-alerts",
            get(list_publish_performance_alerts),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/performance-alerts/process",
            post(process_performance_alerts),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/jobs/{job_id}/cancel",
            post(cancel_publish_job),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/jobs/{job_id}/retry",
            post(retry_publish_job),
        )
        .route(
            "/api/v1/projects/{project_id}/publish/jobs/{job_id}/confirm-semi-auto",
            post(confirm_publish_job_semi_auto),
        )
}

/// Aggregated endpoint for short-video-space publish overview (J.4)
/// Returns all publish-related data in a single request to reduce API fanout
#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/overview",
    operation_id = "getPublishOverviewV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Option<Uuid>, Query, description = "Optional draft ID to fetch prepare check for"),
        ("audit_limit" = Option<i64>, Query, description = "Audit limit (default: 30)")
    ),
    responses(
        (status = 200, description = "OK", body = PublishOverviewResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn publish_overview(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(query): Query<PublishOverviewQuery>,
    headers: HeaderMap,
) -> Result<Json<PublishOverviewResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    // J.6: Deduplicate concurrent identical requests
    let dedupe_key =
        RequestDedupeKey::publish_overview(uid, project_id, query.draft_id, query.audit_limit);

    let result_json = dedupe_publish_overview(dedupe_key, || async {
        // Fetch all data in parallel for optimal performance
        let (drafts_rows, jobs_rows, perf_alerts_rows, audit_rows) = tokio::try_join!(
            list_drafts(pool, project_id, None),
            list_jobs(pool, project_id),
            list_low_performance_alerts(pool, project_id, 1000, 0.45, 50),
            list_attempt_audit(
                pool,
                project_id,
                ListAttemptAuditFilter {
                    draft_id: None,
                    job_id: None,
                    delivery_mode: None,
                    evidence_key: None,
                    limit: query.audit_limit,
                },
            ),
        )?;

        // Convert rows to responses
        let drafts = drafts_rows.into_iter().map(draft_from_row).collect();
        let jobs = jobs_rows.into_iter().map(job_from_row).collect();
        let performance_alerts = perf_alerts_rows
            .into_iter()
            .map(performance_alert_from_row)
            .collect();
        let audit = audit_rows.into_iter().map(attempt_audit_from_row).collect();

        // Optionally fetch prepare check if draft_id is provided
        let prepare_check = if let Some(draft_id) = query.draft_id {
            if let Some(draft) = fetch_draft(pool, project_id, draft_id).await? {
                let targets = list_targets(pool, draft_id).await?;
                let issues = prepare_check_for_draft(&draft, &targets);
                let ok = !issues.iter().any(|i| i.severity == "blocking");
                Some(PublishPrepareCheckResponse {
                    draft_id,
                    ok,
                    issues,
                })
            } else {
                None
            }
        } else {
            None
        };

        let response = PublishOverviewResponse {
            matrix: audit::platform_matrix_body(),
            drafts,
            prepare_check,
            jobs,
            performance_alerts,
            audit,
        };

        // Serialize to JSON for caching
        serde_json::to_value(&response)
            .map_err(|e| ApiError::BadRequest(format!("Failed to serialize response: {}", e)))
    })
    .await?;

    // Deserialize back to typed response
    let response: PublishOverviewResponse = serde_json::from_value(result_json)
        .map_err(|e| ApiError::BadRequest(format!("Failed to deserialize response: {}", e)))?;

    Ok(Json(response))
}
