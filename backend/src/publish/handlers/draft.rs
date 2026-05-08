//! Draft CRUD handlers

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::state::AppState;

use super::super::access::{profile_belongs_to_project, script_belongs_to_project};
use super::super::draft_from_row;
use super::super::store::{
    delete_draft, fetch_draft, insert_draft, list_drafts, patch_draft_row, ScheduledDraftUtcWindow,
};
use super::super::types::{
    CreatePublishDraftBody, ListPublishDraftsQuery, PatchPublishDraftBody, PublishDraftResponse,
};

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
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let window = resolve_scheduled_draft_window(&q)?;
    let rows = list_drafts(pool, project_id, window).await?;
    Ok(Json(rows.into_iter().map(draft_from_row).collect()))
}

pub(super) fn resolve_scheduled_draft_window(
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

pub(super) fn validate_draft_status(raw: &str) -> Result<(), ApiError> {
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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
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
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

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
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
    if delete_draft(pool, project_id, draft_id).await? {
        Ok(axum::http::StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::NotFound)
    }
}
