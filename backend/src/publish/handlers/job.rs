//! Job handlers

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::scope::owned_script_numeric_in_project;
use crate::state::AppState;

use super::super::job_from_row;
use super::super::state_machine::{can_cancel, can_confirm_semi_auto, can_retry};
use super::super::store::{
    cancel_job_if_non_terminal, confirm_semi_auto_job, fetch_draft, fetch_job_owned,
    insert_publish_job, list_jobs, list_targets, retry_job_if_allowed,
};
use super::super::types::{CreatePublishJobBody, PublishJobResponse, PublishPrepareCheckResponse};
use super::super::validation::prepare_check_for_draft;

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
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let draft = fetch_draft(pool, project_id, draft_id)
        .await?
        .ok_or(ApiError::NotFound)?;

    // Run quality gate validation before queueing publish job
    if let Some(script_id_uuid) = draft.script_id {
        use crate::production::{enforce_quality_gate, run_quality_gate, QualityGateStage};

        let numeric_scope = owned_script_numeric_in_project(pool, uid, project_id, script_id_uuid)
            .await
            .map_err(|e| e.into_api_error())?;

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
            numeric_scope.project_numeric_id,
            numeric_scope.script_numeric_id,
            QualityGateStage::VideoGenerate,
            &storyboard_ids,
            &[], // No additional context
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
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let rows = list_jobs(pool, project_id).await?;
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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
    let job = fetch_job_owned(pool, project_id, job_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    if !can_cancel(&job.status) {
        return Err(ApiError::Conflict("job already in terminal status".into()));
    }
    if cancel_job_if_non_terminal(pool, project_id, job_id).await? {
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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
    let job = fetch_job_owned(pool, project_id, job_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    if !can_retry(&job.status) {
        return Err(ApiError::Conflict(
            "job cannot be retried from current status".into(),
        ));
    }
    if retry_job_if_allowed(pool, project_id, job_id).await? {
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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
    let job = fetch_job_owned(pool, project_id, job_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    if !can_confirm_semi_auto(&job.status) {
        return Err(ApiError::Conflict(
            "job is not awaiting semi-auto confirmation".into(),
        ));
    }
    if !confirm_semi_auto_job(pool, project_id, job_id).await? {
        return Err(ApiError::Conflict("confirmation not applied".into()));
    }

    let updated = fetch_job_owned(pool, project_id, job_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(job_from_row(updated)))
}
