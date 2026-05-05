//! HTTP handlers for `/api/v1/projects/{project_id}/publish/*` (**E9**).

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::access::{profile_belongs_to_project, require_project_owned, script_belongs_to_project};
use super::platform_registry::capability_matrix;
use super::state_machine::{can_cancel, can_confirm_semi_auto, can_retry};
use super::store::{
    cancel_job_if_non_terminal, confirm_semi_auto_job, delete_draft, delete_profile, fetch_draft,
    fetch_job_owned, fetch_profile, insert_draft, insert_profile, insert_publish_job, list_drafts,
    list_jobs, list_profiles, list_targets, patch_draft_row, patch_profile_row, replace_targets,
    retry_job_if_allowed,
};
use super::types::{
    CreatePublishDraftBody, CreatePublishJobBody, CreatePublishProfileBody, PatchPublishDraftBody,
    PatchPublishProfileBody, PublishDraftResponse, PublishJobResponse,
    PublishPlatformMatrixResponse, PublishPrepareCheckResponse, PublishProfileResponse,
    PublishTargetResponse, UpsertPublishTargetsBody,
};
use super::validation::{prepare_check_for_draft, validate_automation_mode};
use super::{draft_from_row, job_from_row, profile_from_row, target_from_row};

pub fn router() -> Router<AppState> {
    Router::new()
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
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = Vec<PublishDraftResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_drafts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishDraftResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;
    let rows = list_drafts(pool, project_id).await?;
    Ok(Json(rows.into_iter().map(draft_from_row).collect()))
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
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
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
    if fetch_draft(pool, project_id, draft_id).await?.is_none() {
        return Err(ApiError::NotFound);
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
