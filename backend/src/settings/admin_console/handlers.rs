use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::error::helpers::{bad_request_i18n, forbidden_i18n};
use crate::error::ApiError;
use crate::internal_ops::{expected_internal_ops_token, request_internal_ops_token};
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
    expected_internal_ops_token()
}

fn require_internal_ops_token(headers: &HeaderMap) -> Result<(), ApiError> {
    let Some(expected) = internal_ops_token_expected() else {
        return Err(forbidden_i18n(
            "internal admin console disabled (set OPENFLOW_INTERNAL_OPS_TOKEN)",
            "内部管理控制台已禁用（请设置 OPENFLOW_INTERNAL_OPS_TOKEN）",
        ));
    };
    let got = request_internal_ops_token(headers).unwrap_or_default();
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
        return Err(bad_request_i18n(
            "q must be at least 2 characters",
            "q 必须至少包含 2 个字符",
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

/// Workspace billing query endpoint (Task 8.1).
/// Returns workspace billing information including subscription, quota, and usage aggregates.
/// PII hygiene: only aggregates, no individual user data beyond workspace owner.
#[utoipa::path(
    get,
    path = "/api/v1/internal/admin/workspaces/billing",
    operation_id = "getInternalAdminWorkspaceBillingV1",
    tag = "settings",
    params(super::types::AdminWorkspaceBillingQuery),
    responses(
        (status = 200, description = "OK", body = Vec<super::types::AdminWorkspaceBillingResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_admin_workspace_billing(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<super::types::AdminWorkspaceBillingQuery>,
) -> Result<Json<Vec<super::types::AdminWorkspaceBillingResponse>>, ApiError> {
    require_internal_ops_token(&headers)?;
    let response = storage::get_admin_workspace_billing(&state, query).await?;
    Ok(Json(response))
}
