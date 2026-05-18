//! Internal admin console for operators.
//!
//! Guarded by `OPENFLOW_INTERNAL_OPS_TOKEN` / `X-OpenFlow-Internal-Token`.

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
    __path_get_admin_workspace_billing, __path_get_admin_workspace_detail,
    __path_post_admin_project_batch_governance, __path_post_admin_project_governance,
    __path_post_admin_project_owner_transfer, __path_post_admin_user_governance,
    __path_post_admin_user_workspace_context, __path_post_admin_workspace_governance,
    __path_post_admin_workspace_member_remediation, __path_post_admin_workspace_owner_transfer,
};
pub(crate) use handlers::{
    get_admin_project_detail, get_admin_search, get_admin_user_detail, get_admin_workspace_billing,
    get_admin_workspace_detail, post_admin_project_batch_governance, post_admin_project_governance,
    post_admin_project_owner_transfer, post_admin_user_governance,
    post_admin_user_workspace_context, post_admin_workspace_governance,
    post_admin_workspace_member_remediation, post_admin_workspace_owner_transfer,
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
            "/api/v1/internal/admin/workspaces/billing",
            get(get_admin_workspace_billing),
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
            "/api/v1/internal/admin/workspaces/{workspace_id}/owner-transfer",
            post(post_admin_workspace_owner_transfer),
        )
        .route(
            "/api/v1/internal/admin/projects/{project_id}",
            get(get_admin_project_detail),
        )
        .route(
            "/api/v1/internal/admin/projects/{project_id}/governance",
            post(post_admin_project_governance),
        )
        .route(
            "/api/v1/internal/admin/projects/batch-governance",
            post(post_admin_project_batch_governance),
        )
        .route(
            "/api/v1/internal/admin/projects/{project_id}/owner-transfer",
            post(post_admin_project_owner_transfer),
        )
}

#[cfg(test)]
mod tests {
    use crate::error::helpers::{bad_request_i18n, conflict_i18n, forbidden_i18n};
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
    use crate::error::ApiError;
    use axum::body::to_bytes;
    use axum::response::IntoResponse;

    #[test]
    fn admin_console_disabled_error_creates_correct_variant() {
        let err = forbidden_i18n(
            "internal admin console disabled (set OPENFLOW_INTERNAL_OPS_TOKEN)",
            "内部管理控制台已禁用（请设置 OPENFLOW_INTERNAL_OPS_TOKEN）",
        );
        match err {
            ApiError::Forbidden(msg) => {
                assert!(
                    msg.contains("internal admin console disabled")
                        || msg.contains("内部管理控制台已禁用")
                );
            }
            _ => panic!("expected Forbidden variant"),
        }
    }

    #[tokio::test]
    async fn admin_console_disabled_error_response_en() {
        let err = forbidden_i18n(
            "internal admin console disabled (set OPENFLOW_INTERNAL_OPS_TOKEN)",
            "内部管理控制台已禁用（请设置 OPENFLOW_INTERNAL_OPS_TOKEN）",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("internal admin console disabled"));
    }

    #[tokio::test]
    async fn admin_console_disabled_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = forbidden_i18n(
                    "internal admin console disabled (set OPENFLOW_INTERNAL_OPS_TOKEN)",
                    "内部管理控制台已禁用（请设置 OPENFLOW_INTERNAL_OPS_TOKEN）",
                );
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("内部管理控制台已禁用"));
    }

    #[test]
    fn admin_search_min_length_error_creates_correct_variant() {
        let err = bad_request_i18n("q must be at least 2 characters", "q 必须至少包含 2 个字符");
        match err {
            ApiError::BadRequest(msg) => {
                assert!(
                    msg == "q must be at least 2 characters" || msg == "q 必须至少包含 2 个字符"
                );
            }
            _ => panic!("expected BadRequest variant"),
        }
    }

    #[tokio::test]
    async fn admin_search_min_length_error_response_en() {
        let err = bad_request_i18n("q must be at least 2 characters", "q 必须至少包含 2 个字符");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("q must be at least 2 characters")
        );
    }

    #[tokio::test]
    async fn admin_search_min_length_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err =
                    bad_request_i18n("q must be at least 2 characters", "q 必须至少包含 2 个字符");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("q 必须至少包含 2 个字符")
        );
    }

    #[test]
    fn workspace_owner_transfer_conflict_creates_correct_variant() {
        let err = conflict_i18n(
            "workspace owner role must use owner-transfer flow",
            "工作区所有者角色必须使用所有者转移流程",
        );
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, "workspace owner role must use owner-transfer flow");
                assert_eq!(zh, "工作区所有者角色必须使用所有者转移流程");
            }
            _ => panic!("expected ConflictI18n variant"),
        }
    }

    #[tokio::test]
    async fn workspace_owner_transfer_conflict_response_en() {
        let err = conflict_i18n(
            "workspace owner role must use owner-transfer flow",
            "工作区所有者角色必须使用所有者转移流程",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("workspace owner role must use owner-transfer flow")
        );
    }

    #[tokio::test]
    async fn workspace_owner_transfer_conflict_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "workspace owner role must use owner-transfer flow",
                    "工作区所有者角色必须使用所有者转移流程",
                );
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("工作区所有者角色必须使用所有者转移流程")
        );
    }
}
