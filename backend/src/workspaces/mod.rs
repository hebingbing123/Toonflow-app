use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::error::ApiError;

mod http;
mod ops_stats;

#[derive(Debug, Clone, FromRow)]
pub struct WorkspaceContext {
    pub workspace_id: Uuid,
    pub workspace_name: String,
    pub workspace_type: String,
}

pub fn router() -> axum::Router<crate::state::AppState> {
    http::router().merge(ops_stats::router())
}

pub struct WorkspacesOpenApi;

impl utoipa::OpenApi for WorkspacesOpenApi {
    fn openapi() -> utoipa::openapi::OpenApi {
        let mut doc = <http::WorkspacesOpenApi as utoipa::OpenApi>::openapi();
        doc.merge(<ops_stats::WorkspaceOpsStatsOpenApi as utoipa::OpenApi>::openapi());
        doc
    }
}

pub async fn ensure_personal_workspace(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<WorkspaceContext, ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (owner_user_id, name, workspace_type)
        VALUES ($1, 'Personal Workspace', 'personal')
        ON CONFLICT DO NOTHING
        "#,
    )
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let workspace = sqlx::query_as::<_, WorkspaceContext>(
        r#"
        SELECT
          w.id AS workspace_id,
          w.name AS workspace_name,
          w.workspace_type
        FROM public.app_workspace w
        WHERE w.owner_user_id = $1
          AND w.workspace_type = 'personal'
        ORDER BY w.created_at ASC, w.id ASC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, 'owner')
        ON CONFLICT (workspace_id, user_id) DO NOTHING
        "#,
    )
    .bind(workspace.workspace_id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, current_workspace_id)
        VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE
        SET
          current_workspace_id = COALESCE(public.app_user_profile.current_workspace_id, EXCLUDED.current_workspace_id),
          updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(workspace.workspace_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(workspace)
}

#[cfg(test)]
mod tests {
    use crate::error::helpers::{conflict_i18n, forbidden_i18n};
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
    use crate::error::ApiError;
    use axum::body::to_bytes;
    use axum::response::IntoResponse;

    // ========== Conflict Error Tests ==========

    #[test]
    fn cannot_demote_last_owner_error_creates_correct_variant() {
        let err = conflict_i18n(
            "cannot demote the last workspace owner",
            "不能降级最后一个工作区所有者",
        );
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, "cannot demote the last workspace owner");
                assert_eq!(zh, "不能降级最后一个工作区所有者");
            }
            _ => panic!("expected ConflictI18n variant"),
        }
    }

    #[tokio::test]
    async fn cannot_demote_last_owner_error_response_en() {
        let err = conflict_i18n(
            "cannot demote the last workspace owner",
            "不能降级最后一个工作区所有者",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("cannot demote the last workspace owner"));
    }

    #[tokio::test]
    async fn cannot_demote_last_owner_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "cannot demote the last workspace owner",
                    "不能降级最后一个工作区所有者",
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("不能降级最后一个工作区所有者"));
    }

    #[tokio::test]
    async fn cannot_remove_last_owner_error_response_en() {
        let err = conflict_i18n(
            "cannot remove the last workspace owner",
            "不能移除最后一个工作区所有者",
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
            Some("cannot remove the last workspace owner")
        );
    }

    #[tokio::test]
    async fn cannot_remove_last_owner_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "cannot remove the last workspace owner",
                    "不能移除最后一个工作区所有者",
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
            Some("不能移除最后一个工作区所有者")
        );
    }

    #[tokio::test]
    async fn cannot_leave_as_last_owner_error_response_en() {
        let err = conflict_i18n(
            "cannot leave workspace as the last owner",
            "不能作为最后一个所有者离开工作区",
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
            Some("cannot leave workspace as the last owner")
        );
    }

    #[tokio::test]
    async fn cannot_leave_as_last_owner_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "cannot leave workspace as the last owner",
                    "不能作为最后一个所有者离开工作区",
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
            Some("不能作为最后一个所有者离开工作区")
        );
    }

    #[tokio::test]
    async fn target_owner_must_differ_error_response_en() {
        let err = conflict_i18n(
            "target owner must differ from current owner",
            "目标所有者必须与当前所有者不同",
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
            Some("target owner must differ from current owner")
        );
    }

    #[tokio::test]
    async fn target_owner_must_differ_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "target owner must differ from current owner",
                    "目标所有者必须与当前所有者不同",
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
            Some("目标所有者必须与当前所有者不同")
        );
    }

    #[tokio::test]
    async fn only_current_owner_may_transfer_error_response_en() {
        let err = conflict_i18n(
            "only the current primary owner may transfer ownership",
            "只有当前主要所有者可以转移所有权",
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
            Some("only the current primary owner may transfer ownership")
        );
    }

    #[tokio::test]
    async fn only_current_owner_may_transfer_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "only the current primary owner may transfer ownership",
                    "只有当前主要所有者可以转移所有权",
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
            Some("只有当前主要所有者可以转移所有权")
        );
    }

    #[tokio::test]
    async fn target_must_be_member_error_response_en() {
        let err = conflict_i18n(
            "target user must already be a workspace member",
            "目标用户必须已经是工作区成员",
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
            Some("target user must already be a workspace member")
        );
    }

    #[tokio::test]
    async fn target_must_be_member_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "target user must already be a workspace member",
                    "目标用户必须已经是工作区成员",
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
            Some("目标用户必须已经是工作区成员")
        );
    }

    #[tokio::test]
    async fn invite_cannot_be_revoked_error_response_en() {
        let err = conflict_i18n(
            "invite cannot be revoked (not pending)",
            "邀请无法撤销（不是待处理状态）",
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
            Some("invite cannot be revoked (not pending)")
        );
    }

    #[tokio::test]
    async fn invite_cannot_be_revoked_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "invite cannot be revoked (not pending)",
                    "邀请无法撤销（不是待处理状态）",
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
            Some("邀请无法撤销（不是待处理状态）")
        );
    }

    #[tokio::test]
    async fn invite_cannot_be_resent_error_response_en() {
        let err = conflict_i18n(
            "invite cannot be resent (not pending)",
            "邀请无法重发（不是待处理状态）",
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
            Some("invite cannot be resent (not pending)")
        );
    }

    #[tokio::test]
    async fn invite_cannot_be_resent_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n(
                    "invite cannot be resent (not pending)",
                    "邀请无法重发（不是待处理状态）",
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
            Some("邀请无法重发（不是待处理状态）")
        );
    }

    #[tokio::test]
    async fn invite_not_pending_error_response_en() {
        let err = conflict_i18n("invite is not pending", "邀请不是待处理状态");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("invite is not pending")
        );
    }

    #[tokio::test]
    async fn invite_not_pending_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n("invite is not pending", "邀请不是待处理状态");
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
            Some("邀请不是待处理状态")
        );
    }

    #[tokio::test]
    async fn invite_expired_error_response_en() {
        let err = conflict_i18n("invite has expired", "邀请已过期");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("invite has expired")
        );
    }

    #[tokio::test]
    async fn invite_expired_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = conflict_i18n("invite has expired", "邀请已过期");
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
            Some("邀请已过期")
        );
    }

    // ========== Forbidden Error Tests ==========

    #[tokio::test]
    async fn not_workspace_member_error_response_en() {
        let err = forbidden_i18n("not a workspace member", "不是工作区成员");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("not a workspace member")
        );
    }

    #[tokio::test]
    async fn not_workspace_member_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = forbidden_i18n("not a workspace member", "不是工作区成员");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("不是工作区成员")
        );
    }

    #[tokio::test]
    async fn requires_owner_or_admin_error_response_en() {
        let err = forbidden_i18n(
            "requires workspace owner or admin",
            "需要工作区所有者或管理员权限",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("requires workspace owner or admin")
        );
    }

    #[tokio::test]
    async fn requires_owner_or_admin_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = forbidden_i18n(
                    "requires workspace owner or admin",
                    "需要工作区所有者或管理员权限",
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
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("需要工作区所有者或管理员权限")
        );
    }

    #[tokio::test]
    async fn requires_owner_error_response_en() {
        let err = forbidden_i18n("requires workspace owner", "需要工作区所有者权限");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("requires workspace owner")
        );
    }

    #[tokio::test]
    async fn requires_owner_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = forbidden_i18n("requires workspace owner", "需要工作区所有者权限");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("需要工作区所有者权限")
        );
    }

    #[tokio::test]
    async fn workspace_stats_http_disabled_error_response_en() {
        let err = forbidden_i18n(
            "workspace stats HTTP disabled (set TOONFLOW_INTERNAL_OPS_TOKEN)",
            "工作区统计 HTTP 已禁用（请设置 TOONFLOW_INTERNAL_OPS_TOKEN）",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("workspace stats HTTP disabled"));
    }

    #[tokio::test]
    async fn workspace_stats_http_disabled_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = forbidden_i18n(
                    "workspace stats HTTP disabled (set TOONFLOW_INTERNAL_OPS_TOKEN)",
                    "工作区统计 HTTP 已禁用（请设置 TOONFLOW_INTERNAL_OPS_TOKEN）",
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
        assert!(message.contains("工作区统计 HTTP 已禁用"));
    }
}
