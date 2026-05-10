//! Internal admin console for operators.
//!
//! Guarded by `TOONFLOW_INTERNAL_OPS_TOKEN` / `X-Toonflow-Internal-Token`.

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_get_admin_project_detail, __path_get_admin_search, __path_get_admin_user_detail,
    __path_get_admin_workspace_detail, __path_post_admin_project_governance,
    __path_post_admin_user_governance, __path_post_admin_user_workspace_context,
    __path_post_admin_workspace_governance, __path_post_admin_workspace_member_remediation,
};
pub(crate) use handlers::{
    get_admin_project_detail, get_admin_search, get_admin_user_detail, get_admin_workspace_detail,
    post_admin_project_governance, post_admin_user_governance, post_admin_user_workspace_context,
    post_admin_workspace_governance, post_admin_workspace_member_remediation,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/internal/admin/search", get(get_admin_search))
        .route(
            "/api/v1/internal/admin/users/{user_id}",
            get(get_admin_user_detail),
        )
        .route(
            "/api/v1/internal/admin/users/{user_id}/governance",
            post(post_admin_user_governance),
        )
        .route(
            "/api/v1/internal/admin/users/{user_id}/workspace-context",
            post(post_admin_user_workspace_context),
        )
        .route(
            "/api/v1/internal/admin/workspaces/{workspace_id}",
            get(get_admin_workspace_detail),
        )
        .route(
            "/api/v1/internal/admin/workspaces/{workspace_id}/governance",
            post(post_admin_workspace_governance),
        )
        .route(
            "/api/v1/internal/admin/workspaces/{workspace_id}/members/remediation",
            post(post_admin_workspace_member_remediation),
        )
        .route(
            "/api/v1/internal/admin/projects/{project_id}",
            get(get_admin_project_detail),
        )
        .route(
            "/api/v1/internal/admin/projects/{project_id}/governance",
            post(post_admin_project_governance),
        )
}
