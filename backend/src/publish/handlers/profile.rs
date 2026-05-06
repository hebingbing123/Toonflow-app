//! Profile handlers for publish.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::access::require_project_owned;
use super::super::profile_from_row;
use super::super::store::{
    delete_profile, fetch_profile, insert_profile, list_profiles, patch_profile_row,
};
use super::super::types::{
    CreatePublishProfileBody, PatchPublishProfileBody, PublishProfileResponse,
};

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
