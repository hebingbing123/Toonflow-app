//! HTTP handlers for `/api/v1/projects/{project_id}/publish/*` (**E9**).

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::request_dedupe::{dedupe_publish_overview, RequestDedupeKey};
use crate::state::AppState;

use super::access::{profile_belongs_to_project, require_project_owned, script_belongs_to_project};
use super::platform_registry::capability_matrix;
use super::state_machine::{can_cancel, can_confirm_semi_auto, can_retry};
use super::store::{
    cancel_job_if_non_terminal, confirm_semi_auto_job, delete_draft, delete_profile, fetch_draft,
    fetch_job_owned, fetch_profile, insert_draft, insert_profile, insert_publish_job,
    list_attempt_audit, list_drafts, list_jobs, list_low_performance_alerts, list_profiles,
    list_targets, patch_draft_row, patch_profile_row, replace_targets, retry_job_if_allowed,
    ListAttemptAuditFilter, ScheduledDraftUtcWindow,
};
use super::types::{
    CreatePublishDraftBody, CreatePublishJobBody, CreatePublishProfileBody, ListPublishAuditQuery,
    ListPublishDraftsQuery, ListPublishPerformanceAlertsQuery, PatchPublishDraftBody,
    PatchPublishProfileBody, PublishAttemptAuditResponse, PublishDraftResponse, PublishJobResponse,
    PublishOverviewQuery, PublishOverviewResponse, PublishPerformanceAlertResponse,
    PublishPlatformMatrixResponse, PublishPrepareCheckResponse, PublishProfileResponse,
    PublishTargetResponse, UpsertPublishTargetsBody,
};
use super::validation::{prepare_check_for_draft, validate_automation_mode};
use super::{
    attempt_audit_from_row, draft_from_row, job_from_row, performance_alert_from_row,
    profile_from_row, target_from_row,
};

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

fn platform_matrix_body() -> PublishPlatformMatrixResponse {
    PublishPlatformMatrixResponse {
        platforms: capability_matrix(),
    }
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
    require_project_owned(pool, uid, project_id).await?;

    // J.6: Deduplicate concurrent identical requests
    let dedupe_key =
        RequestDedupeKey::publish_overview(uid, project_id, query.draft_id, query.audit_limit);

    let result_json = dedupe_publish_overview(dedupe_key, || async {
        // Fetch all data in parallel for optimal performance
        let (drafts_rows, jobs_rows, perf_alerts_rows, audit_rows) = tokio::try_join!(
            list_drafts(pool, project_id, None),
            list_jobs(pool, project_id, uid),
            list_low_performance_alerts(pool, project_id, uid, 1000, 0.45, 50),
            list_attempt_audit(
                pool,
                project_id,
                uid,
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
        let drafts: Vec<PublishDraftResponse> =
            drafts_rows.into_iter().map(draft_from_row).collect();
        let jobs: Vec<PublishJobResponse> = jobs_rows.into_iter().map(job_from_row).collect();
        let performance_alerts: Vec<PublishPerformanceAlertResponse> = perf_alerts_rows
            .into_iter()
            .map(performance_alert_from_row)
            .collect();
        let audit: Vec<PublishAttemptAuditResponse> =
            audit_rows.into_iter().map(attempt_audit_from_row).collect();

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
            matrix: platform_matrix_body(),
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

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/platform-matrix",
    operation_id = "getPublishPlatformMatrixV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = PublishPlatformMatrixResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn publish_platform_matrix(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<PublishPlatformMatrixResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    Ok(Json(platform_matrix_body()))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/profiles",
    operation_id = "listPublishProfilesV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = Vec<PublishProfileResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_profiles(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishProfileResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let rows = list_profiles(pool, project_id).await?;
    Ok(Json(rows.into_iter().map(profile_from_row).collect()))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/profiles",
    operation_id = "createPublishProfileV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = CreatePublishProfileBody,
    responses(
        (status = 200, description = "Created", body = PublishProfileResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_publish_profile(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreatePublishProfileBody>,
) -> Result<Json<PublishProfileResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    if body.name.trim().is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }
    let row = insert_profile(pool, project_id, &body).await?;
    Ok(Json(profile_from_row(row)))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/profiles/{profile_id}",
    operation_id = "getPublishProfileV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("profile_id" = Uuid, Path, description = "Profile UUID")
    ),
    responses(
        (status = 200, description = "OK", body = PublishProfileResponse),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_publish_profile(
    State(state): State<AppState>,
    Path((project_id, profile_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<PublishProfileResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let row = fetch_profile(pool, project_id, profile_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(profile_from_row(row)))
}

#[utoipa::path(
    patch,
    path = "/api/v1/projects/{project_id}/publish/profiles/{profile_id}",
    operation_id = "patchPublishProfileV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("profile_id" = Uuid, Path, description = "Profile UUID")
    ),
    request_body = PatchPublishProfileBody,
    responses(
        (status = 200, description = "OK", body = PublishProfileResponse),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_publish_profile(
    State(state): State<AppState>,
    Path((project_id, profile_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<PatchPublishProfileBody>,
) -> Result<Json<PublishProfileResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    if let Some(ref name) = body.name {
        if name.trim().is_empty() {
            return Err(ApiError::BadRequest("name must not be empty".into()));
        }
    }
    let row = patch_profile_row(pool, project_id, profile_id, &body)
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(profile_from_row(row)))
}

#[utoipa::path(
    delete,
    path = "/api/v1/projects/{project_id}/publish/profiles/{profile_id}",
    operation_id = "deletePublishProfileV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("profile_id" = Uuid, Path, description = "Profile UUID")
    ),
    responses(
        (status = 204, description = "Deleted"),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_publish_profile(
    State(state): State<AppState>,
    Path((project_id, profile_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<axum::http::StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    if delete_profile(pool, project_id, profile_id).await? {
        Ok(axum::http::StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::NotFound)
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/drafts",
    operation_id = "listPublishDraftsV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        (
            "scheduled_from" = Option<String>,
            Query,
            description = "RFC3339 inclusive lower bound; requires `scheduled_to`."
        ),
        (
            "scheduled_to" = Option<String>,
            Query,
            description = "RFC3339 exclusive upper bound; requires `scheduled_from`."
        )
    ),
    responses(
        (status = 200, description = "OK", body = Vec<PublishDraftResponse>),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_drafts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(q): Query<ListPublishDraftsQuery>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishDraftResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let window = resolve_scheduled_draft_window(&q)?;
    let rows = list_drafts(pool, project_id, window).await?;
    Ok(Json(rows.into_iter().map(draft_from_row).collect()))
}

fn resolve_scheduled_draft_window(
    q: &ListPublishDraftsQuery,
) -> Result<Option<ScheduledDraftUtcWindow>, ApiError> {
    match (&q.scheduled_from, &q.scheduled_to) {
        (None, None) => Ok(None),
        (Some(from_s), Some(to_s)) => {
            let from: DateTime<Utc> = from_s
                .trim()
                .parse()
                .map_err(|_| ApiError::BadRequest("scheduled_from must be valid RFC3339".into()))?;
            let to_excl: DateTime<Utc> = to_s
                .trim()
                .parse()
                .map_err(|_| ApiError::BadRequest("scheduled_to must be valid RFC3339".into()))?;
            if from >= to_excl {
                return Err(ApiError::BadRequest(
                    "scheduled_from must be strictly before scheduled_to".into(),
                ));
            }
            Ok(Some((from, to_excl)))
        }
        _ => Err(ApiError::BadRequest(
            "scheduled_from and scheduled_to must both be set when filtering".into(),
        )),
    }
}

fn validate_draft_status(raw: &str) -> Result<(), ApiError> {
    match raw {
        "editing" | "ready" | "archived" => Ok(()),
        _ => Err(ApiError::BadRequest(
            "draft_status must be editing, ready, or archived".into(),
        )),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts",
    operation_id = "createPublishDraftV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = CreatePublishDraftBody,
    responses(
        (status = 200, description = "Created", body = PublishDraftResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_publish_draft(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreatePublishDraftBody>,
) -> Result<Json<PublishDraftResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    validate_draft_status(body.draft_status.trim())?;

    if let Some(pid) = body.profile_id {
        if !profile_belongs_to_project(pool, pid, project_id).await? {
            return Err(ApiError::BadRequest(
                "profile_id does not belong to project".into(),
            ));
        }
    }
    if let Some(sid) = body.script_id {
        if !script_belongs_to_project(pool, sid, project_id).await? {
            return Err(ApiError::BadRequest(
                "script_id does not belong to project".into(),
            ));
        }
    }

    let row = insert_draft(pool, project_id, &body).await?;
    Ok(Json(draft_from_row(row)))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}",
    operation_id = "getPublishDraftV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    responses(
        (status = 200, description = "OK", body = PublishDraftResponse),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_publish_draft(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<PublishDraftResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let row = fetch_draft(pool, project_id, draft_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(draft_from_row(row)))
}

#[utoipa::path(
    patch,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}",
    operation_id = "patchPublishDraftV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    request_body = PatchPublishDraftBody,
    responses(
        (status = 200, description = "OK", body = PublishDraftResponse),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_publish_draft(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<PatchPublishDraftBody>,
) -> Result<Json<PublishDraftResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;

    if let Some(ref ds) = body.draft_status {
        validate_draft_status(ds.trim())?;
    }
    if let Some(pid) = body.profile_id {
        if !profile_belongs_to_project(pool, pid, project_id).await? {
            return Err(ApiError::BadRequest(
                "profile_id does not belong to project".into(),
            ));
        }
    }
    if let Some(sid) = body.script_id {
        if !script_belongs_to_project(pool, sid, project_id).await? {
            return Err(ApiError::BadRequest(
                "script_id does not belong to project".into(),
            ));
        }
    }

    let row = patch_draft_row(pool, project_id, draft_id, &body)
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(draft_from_row(row)))
}

#[utoipa::path(
    delete,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}",
    operation_id = "deletePublishDraftV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    responses(
        (status = 204, description = "Deleted"),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_publish_draft_handler(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<axum::http::StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    if delete_draft(pool, project_id, draft_id).await? {
        Ok(axum::http::StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::NotFound)
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/targets",
    operation_id = "listPublishTargetsV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    responses(
        (status = 200, description = "OK", body = Vec<PublishTargetResponse>),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_targets(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishTargetResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    if fetch_draft(pool, project_id, draft_id).await?.is_none() {
        return Err(ApiError::NotFound);
    }
    let rows = list_targets(pool, draft_id).await?;
    Ok(Json(rows.into_iter().map(target_from_row).collect()))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/targets",
    operation_id = "upsertPublishTargetsV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    request_body = UpsertPublishTargetsBody,
    responses(
        (status = 200, description = "OK", body = Vec<PublishTargetResponse>),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn upsert_publish_targets(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<UpsertPublishTargetsBody>,
) -> Result<Json<Vec<PublishTargetResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    if fetch_draft(pool, project_id, draft_id).await?.is_none() {
        return Err(ApiError::NotFound);
    }
    for t in &body.targets {
        if t.platform_id.trim().is_empty() {
            return Err(ApiError::BadRequest("platform_id must not be empty".into()));
        }
        validate_automation_mode(t.automation_mode.trim())
            .map_err(|e| ApiError::BadRequest(e.into()))?;
    }
    let rows = replace_targets(pool, draft_id, &body.targets).await?;
    Ok(Json(rows.into_iter().map(target_from_row).collect()))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/prepare-check",
    operation_id = "getPublishDraftPrepareCheckV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    responses(
        (status = 200, description = "OK", body = PublishPrepareCheckResponse),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn publish_prepare_check(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<PublishPrepareCheckResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let draft = fetch_draft(pool, project_id, draft_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    let targets = list_targets(pool, draft_id).await?;
    let issues = prepare_check_for_draft(&draft, &targets);
    let ok = !issues.iter().any(|i| i.severity == "blocking");
    Ok(Json(PublishPrepareCheckResponse {
        draft_id,
        ok,
        issues,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/jobs",
    operation_id = "createPublishJobV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Uuid, Path, description = "Draft UUID")
    ),
    request_body = CreatePublishJobBody,
    responses(
        (status = 200, description = "Created", body = PublishJobResponse),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Quality gate blocked", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_publish_job(
    State(state): State<AppState>,
    Path((project_id, draft_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<CreatePublishJobBody>,
) -> Result<Json<PublishJobResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;

    let draft = fetch_draft(pool, project_id, draft_id)
        .await?
        .ok_or(ApiError::NotFound)?;

    // Run quality gate validation before queueing publish job
    if let Some(script_id_uuid) = draft.script_id {
        use crate::production::{enforce_quality_gate, run_quality_gate, QualityGateStage};

        // Convert script UUID to numeric ID
        let script_numeric_id: i32 = sqlx::query_scalar(
            r#"
            SELECT numeric_id
            FROM app_script
            WHERE id = $1
            "#,
        )
        .bind(script_id_uuid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .ok_or(ApiError::NotFound)?;

        // Convert project UUID to numeric ID
        let project_numeric_id: i32 = sqlx::query_scalar(
            r#"
            SELECT numeric_id
            FROM app_project
            WHERE id = $1
            "#,
        )
        .bind(project_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .ok_or(ApiError::NotFound)?;

        // Get all storyboard IDs for this script
        let storyboard_ids: Vec<i32> = sqlx::query_scalar(
            r#"
            SELECT numeric_id
            FROM app_storyboard
            WHERE script_id = $1
            ORDER BY numeric_id ASC
            "#,
        )
        .bind(script_id_uuid)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // Run quality gate check at VideoGenerate stage (publish is after video generation)
        let (gate, strategy) = run_quality_gate(
            pool,
            uid,
            project_numeric_id,
            script_numeric_id,
            QualityGateStage::VideoGenerate,
            &storyboard_ids,
            &[], // No additional text inputs for publish validation
        )
        .await?;

        // Enforce quality gate based on strategy
        enforce_quality_gate(QualityGateStage::VideoGenerate, &gate, strategy)?;
    }

    let row = insert_publish_job(pool, project_id, draft_id, uid, &body).await?;
    Ok(Json(job_from_row(row)))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/jobs",
    operation_id = "listPublishJobsV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = Vec<PublishJobResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_jobs(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishJobResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let rows = list_jobs(pool, project_id, uid).await?;
    Ok(Json(rows.into_iter().map(job_from_row).collect()))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/audit",
    operation_id = "listPublishAuditV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Option<Uuid>, Query, description = "Optional draft filter"),
        ("job_id" = Option<Uuid>, Query, description = "Optional job filter"),
        ("delivery_mode" = Option<String>, Query, description = "Optional delivery-mode filter: sandbox/live/manual_bridge/unknown"),
        ("evidence_key" = Option<String>, Query, description = "Optional evidence key filter: request_id/manual_step_id/callback_id"),
        ("limit" = Option<i64>, Query, description = "1..200, default 50")
    ),
    responses(
        (status = 200, description = "OK", body = Vec<PublishAttemptAuditResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_audit(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(q): Query<ListPublishAuditQuery>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishAttemptAuditResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let rows = list_attempt_audit(
        pool,
        project_id,
        uid,
        ListAttemptAuditFilter {
            draft_id: q.draft_id,
            job_id: q.job_id,
            delivery_mode: q.delivery_mode.as_deref(),
            evidence_key: q.evidence_key.as_deref(),
            limit: q.limit,
        },
    )
    .await?;
    Ok(Json(rows.into_iter().map(attempt_audit_from_row).collect()))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/performance-alerts",
    operation_id = "listPublishPerformanceAlertsV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("views_lt" = Option<i64>, Query, description = "Low-performance views threshold"),
        ("completion_rate_lt" = Option<f64>, Query, description = "Low-performance completion-rate threshold"),
        ("limit" = Option<i64>, Query, description = "1..200, default 50")
    ),
    responses(
        (status = 200, description = "OK", body = Vec<PublishPerformanceAlertResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_performance_alerts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(q): Query<ListPublishPerformanceAlertsQuery>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishPerformanceAlertResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let rows = list_low_performance_alerts(
        pool,
        project_id,
        uid,
        q.views_lt,
        q.completion_rate_lt,
        q.limit,
    )
    .await?;
    Ok(Json(
        rows.into_iter().map(performance_alert_from_row).collect(),
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/jobs/{job_id}/cancel",
    operation_id = "cancelPublishJobV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("job_id" = Uuid, Path, description = "Job UUID")
    ),
    responses(
        (status = 204, description = "Cancelled"),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn cancel_publish_job(
    State(state): State<AppState>,
    Path((project_id, job_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<axum::http::StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let job = fetch_job_owned(pool, project_id, job_id, uid)
        .await?
        .ok_or(ApiError::NotFound)?;
    if !can_cancel(&job.status) {
        return Err(ApiError::Conflict("job already in terminal status".into()));
    }
    if cancel_job_if_non_terminal(pool, project_id, job_id, uid).await? {
        Ok(axum::http::StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::Conflict("job could not be cancelled".into()))
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/jobs/{job_id}/retry",
    operation_id = "retryPublishJobV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("job_id" = Uuid, Path, description = "Job UUID")
    ),
    responses(
        (status = 204, description = "Requeued"),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn retry_publish_job(
    State(state): State<AppState>,
    Path((project_id, job_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<axum::http::StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let job = fetch_job_owned(pool, project_id, job_id, uid)
        .await?
        .ok_or(ApiError::NotFound)?;
    if !can_retry(&job.status) {
        return Err(ApiError::Conflict(
            "job cannot be retried from current status".into(),
        ));
    }
    if retry_job_if_allowed(pool, project_id, job_id, uid).await? {
        Ok(axum::http::StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::Conflict("retry not applied".into()))
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/jobs/{job_id}/confirm-semi-auto",
    operation_id = "confirmSemiAutoPublishJobV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("job_id" = Uuid, Path, description = "Job UUID")
    ),
    responses(
        (status = 200, description = "OK", body = PublishJobResponse),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn confirm_publish_job_semi_auto(
    State(state): State<AppState>,
    Path((project_id, job_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<PublishJobResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let job = fetch_job_owned(pool, project_id, job_id, uid)
        .await?
        .ok_or(ApiError::NotFound)?;
    if !can_confirm_semi_auto(&job.status) {
        return Err(ApiError::Conflict(
            "job is not awaiting semi-auto confirmation".into(),
        ));
    }
    if !confirm_semi_auto_job(pool, project_id, job_id, uid).await? {
        return Err(ApiError::Conflict("confirmation not applied".into()));
    }

    let updated = fetch_job_owned(pool, project_id, job_id, uid)
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(job_from_row(updated)))
}

/// Process low-performance alerts and create quality reviews (I.5)
#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/performance-alerts/process",
    operation_id = "processPerformanceAlertsV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("views_lt" = Option<i64>, Query, description = "Low-performance views threshold (default: 100)"),
        ("completion_rate_lt" = Option<f64>, Query, description = "Low-performance completion-rate threshold (default: 0.3)"),
        ("engagement_rate_lt" = Option<f64>, Query, description = "Low-performance engagement-rate threshold (default: 0.01)"),
        ("limit" = Option<i64>, Query, description = "1..200, default 50")
    ),
    responses(
        (status = 200, description = "Quality reviews created", body = Vec<serde_json::Value>),
        (status = 404, description = "Not found")
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn process_performance_alerts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(query): Query<ListPublishPerformanceAlertsQuery>,
    headers: HeaderMap,
) -> Result<Json<Vec<crate::prompting::quality::QualityReview>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;

    let thresholds = super::performance_rework::PerformanceThresholds {
        min_views: query.views_lt,
        min_completion_rate: query.completion_rate_lt,
        min_engagement_rate: 0.01, // Default engagement rate threshold
        platform_overrides: std::collections::HashMap::new(), // P5: No overrides by default
    };

    let limit = query.limit;

    let reviews = super::performance_rework::process_low_performance_alerts(
        pool,
        project_id,
        uid,
        &thresholds,
        limit,
    )
    .await?;

    Ok(Json(reviews))
}
