//! Target handlers for publish.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::super::store::{fetch_draft, list_targets, replace_targets};
use super::super::target_from_row;
use super::super::types::{PublishTargetResponse, UpsertPublishTargetsBody};
use super::super::validation::validate_automation_mode;

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
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
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
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
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
