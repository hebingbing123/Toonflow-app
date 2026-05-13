use axum::{
    extract::{Json, State},
    http::HeaderMap,
};

use crate::auth::require_user_uuid;
use crate::error::helpers::{bad_request_i18n, forbidden_i18n};
use crate::error::ApiError;
use crate::state::AppState;

use super::storage::{
    clear_user_platform_config, clear_workspace_platform_config, load_platform_config_response,
    resolve_current_workspace_platform_config, save_user_platform_config,
    save_workspace_platform_config,
};
use super::types::{PlatformConfigEnvelope, PlatformConfigResponse, PlatformConfigToggleSet};

fn default_platform_config() -> PlatformConfigToggleSet {
    PlatformConfigToggleSet::default_seeded()
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/platform-config",
    operation_id = "getPlatformConfigV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = PlatformConfigResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_platform_config(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<PlatformConfigResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let defaults = default_platform_config();
    let response = load_platform_config_response(pool, uid, defaults).await?;
    Ok(Json(response))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/platform-config",
    operation_id = "postPlatformConfigV1",
    tag = "settings",
    request_body = PlatformConfigEnvelope,
    responses(
        (status = 200, description = "OK", body = PlatformConfigResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_platform_config(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PlatformConfigEnvelope>,
) -> Result<Json<PlatformConfigResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let reset = body.reset.unwrap_or(false);
    let target_scope = body
        .scope
        .as_deref()
        .map(str::trim)
        .filter(|scope| !scope.is_empty())
        .unwrap_or("user");
    match target_scope {
        "user" => {
            if reset {
                clear_user_platform_config(pool, uid).await?;
            } else {
                let toggles = body.toggles.as_ref().ok_or_else(|| {
                    bad_request_i18n(
                        "toggles are required unless reset=true",
                        "除非 reset=true，否则 toggles 为必填项",
                    )
                })?;
                save_user_platform_config(pool, uid, toggles).await?;
            }
        }
        "workspace" => {
            let workspace = resolve_current_workspace_platform_config(pool, uid)
                .await?
                .ok_or_else(|| {
                    bad_request_i18n(
                        "current workspace is unavailable",
                        "当前工作区不可用",
                    )
                })?;
            if !workspace.summary.can_manage_override {
                return Err(forbidden_i18n(
                    "current workspace override requires enterprise owner/admin",
                    "当前工作区覆盖需要企业所有者/管理员权限",
                ));
            }
            if reset {
                clear_workspace_platform_config(pool, workspace.summary.id).await?;
            } else {
                let toggles = body.toggles.as_ref().ok_or_else(|| {
                    bad_request_i18n(
                        "toggles are required unless reset=true",
                        "除非 reset=true，否则 toggles 为必填项",
                    )
                })?;
                save_workspace_platform_config(pool, workspace.summary.id, toggles).await?;
            }
        }
        _ => {
            return Err(bad_request_i18n(
                "scope must be user or workspace",
                "scope 必须为 user 或 workspace",
            ));
        }
    }
    let response = load_platform_config_response(pool, uid, default_platform_config()).await?;
    Ok(Json(response))
}
