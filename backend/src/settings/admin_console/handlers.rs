use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

use super::storage;
use super::types::{
    AdminProjectBatchGovernanceResponse, AdminProjectBatchGovernanceUpdateBody,
    AdminProjectDetailResponse, AdminProjectGovernanceUpdateBody, AdminProjectOwnerTransferBody,
    AdminSearchQuery, AdminSearchResponse, AdminUserDetailResponse, AdminUserGovernanceUpdateBody,
    AdminUserWorkspaceContextUpdateBody, AdminWorkspaceDetailResponse,
    AdminWorkspaceGovernanceUpdateBody, AdminWorkspaceMemberRemediationBody,
    AdminWorkspaceOwnerTransferBody,
};

fn internal_ops_token_expected() -> Option<String> {
    std::env::var("TOONFLOW_INTERNAL_OPS_TOKEN")
        .ok()
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
}

fn require_internal_ops_token(headers: &HeaderMap) -> Result<(), ApiError> {
    let Some(expected) = internal_ops_token_expected() else {
        return Err(ApiError::Forbidden(
            "internal admin console disabled (set TOONFLOW_INTERNAL_OPS_TOKEN)".into(),
        ));
    };
    let got = headers
        .get("x-toonflow-internal-token")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if got != expected.as_str() {
        return Err(ApiError::Unauthorized);
    }
    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/v1/internal/admin/search",
    operation_id = "getInternalAdminSearchV1",
    tag = "settings",
    params(AdminSearchQuery),
    responses(
        (status = 200, description = "OK", body = AdminSearchResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_admin_search(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<AdminSearchQuery>,
) -> Result<Json<AdminSearchResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let needle = query.q.trim();
    if needle.len() < 2 {
        return Err(ApiError::BadRequest(
            "q must be at least 2 characters".into(),
        ));
    }
    let limit = query.limit.unwrap_or(8).clamp(1, 20);
    let response = storage::search_admin_console(&state, needle, limit).await?;
    Ok(Json(response))
}

#[utoipa::path(
    get,
    path = "/api/v1/internal/admin/users/{user_id}",
    operation_id = "getInternalAdminUserDetailV1",
    tag = "settings",
    params(("user_id" = Uuid, Path, description = "User UUID")),
    responses(
        (status = 200, description = "OK", body = AdminUserDetailResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_admin_user_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(user_id): Path<Uuid>,
) -> Result<Json<AdminUserDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::get_admin_user_detail(&state, user_id).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/users/{user_id}/governance",
    operation_id = "postInternalAdminUserGovernanceV1",
    tag = "settings",
    params(("user_id" = Uuid, Path, description = "User UUID")),
    request_body(content = AdminUserGovernanceUpdateBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = AdminUserDetailResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_user_governance(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(user_id): Path<Uuid>,
    Json(body): Json<AdminUserGovernanceUpdateBody>,
) -> Result<Json<AdminUserDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::update_admin_user_governance(&state, user_id, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/users/{user_id}/workspace-context",
    operation_id = "postInternalAdminUserWorkspaceContextV1",
    tag = "settings",
    params(("user_id" = Uuid, Path, description = "User UUID")),
    request_body(content = AdminUserWorkspaceContextUpdateBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = AdminUserDetailResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_user_workspace_context(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(user_id): Path<Uuid>,
    Json(body): Json<AdminUserWorkspaceContextUpdateBody>,
) -> Result<Json<AdminUserDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::update_admin_user_workspace_context(&state, user_id, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    get,
    path = "/api/v1/internal/admin/workspaces/{workspace_id}",
    operation_id = "getInternalAdminWorkspaceDetailV1",
    tag = "settings",
    params(("workspace_id" = Uuid, Path, description = "Workspace UUID")),
    responses(
        (status = 200, description = "OK", body = AdminWorkspaceDetailResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_admin_workspace_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
) -> Result<Json<AdminWorkspaceDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::get_admin_workspace_detail(&state, workspace_id).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/workspaces/{workspace_id}/governance",
    operation_id = "postInternalAdminWorkspaceGovernanceV1",
    tag = "settings",
    params(("workspace_id" = Uuid, Path, description = "Workspace UUID")),
    request_body(
        content = AdminWorkspaceGovernanceUpdateBody,
        content_type = "application/json"
    ),
    responses(
        (status = 200, description = "OK", body = AdminWorkspaceDetailResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_workspace_governance(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Json(body): Json<AdminWorkspaceGovernanceUpdateBody>,
) -> Result<Json<AdminWorkspaceDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::update_admin_workspace_governance(&state, workspace_id, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/workspaces/{workspace_id}/members/remediation",
    operation_id = "postInternalAdminWorkspaceMemberRemediationV1",
    tag = "settings",
    params(("workspace_id" = Uuid, Path, description = "Workspace UUID")),
    request_body(
        content = AdminWorkspaceMemberRemediationBody,
        content_type = "application/json"
    ),
    responses(
        (status = 200, description = "OK", body = AdminWorkspaceDetailResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_workspace_member_remediation(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Json(body): Json<AdminWorkspaceMemberRemediationBody>,
) -> Result<Json<AdminWorkspaceDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response =
        storage::update_admin_workspace_member_remediation(&state, workspace_id, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/workspaces/{workspace_id}/owner-transfer",
    operation_id = "postInternalAdminWorkspaceOwnerTransferV1",
    tag = "settings",
    params(("workspace_id" = Uuid, Path, description = "Workspace UUID")),
    request_body(
        content = AdminWorkspaceOwnerTransferBody,
        content_type = "application/json"
    ),
    responses(
        (status = 200, description = "OK", body = AdminWorkspaceDetailResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_workspace_owner_transfer(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Json(body): Json<AdminWorkspaceOwnerTransferBody>,
) -> Result<Json<AdminWorkspaceDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::transfer_admin_workspace_owner(&state, workspace_id, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/projects/{project_id}/governance",
    operation_id = "postInternalAdminProjectGovernanceV1",
    tag = "settings",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body(
        content = AdminProjectGovernanceUpdateBody,
        content_type = "application/json"
    ),
    responses(
        (status = 200, description = "OK", body = AdminProjectDetailResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_project_governance(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<AdminProjectGovernanceUpdateBody>,
) -> Result<Json<AdminProjectDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::update_admin_project_governance(&state, project_id, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/projects/batch-governance",
    operation_id = "postInternalAdminProjectBatchGovernanceV1",
    tag = "settings",
    request_body(
        content = AdminProjectBatchGovernanceUpdateBody,
        content_type = "application/json"
    ),
    responses(
        (status = 200, description = "OK", body = AdminProjectBatchGovernanceResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_project_batch_governance(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AdminProjectBatchGovernanceUpdateBody>,
) -> Result<Json<AdminProjectBatchGovernanceResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::update_admin_project_batch_governance(&state, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/admin/projects/{project_id}/owner-transfer",
    operation_id = "postInternalAdminProjectOwnerTransferV1",
    tag = "settings",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body(
        content = AdminProjectOwnerTransferBody,
        content_type = "application/json"
    ),
    responses(
        (status = 200, description = "OK", body = AdminProjectDetailResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_admin_project_owner_transfer(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<AdminProjectOwnerTransferBody>,
) -> Result<Json<AdminProjectDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::transfer_admin_project_owner(&state, project_id, body).await?;
    Ok(Json(response))
}

#[utoipa::path(
    get,
    path = "/api/v1/internal/admin/projects/{project_id}",
    operation_id = "getInternalAdminProjectDetailV1",
    tag = "settings",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = AdminProjectDetailResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_admin_project_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
) -> Result<Json<AdminProjectDetailResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::get_admin_project_detail(&state, project_id).await?;
    Ok(Json(response))
}
