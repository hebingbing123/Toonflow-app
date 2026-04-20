//! Axum handler 侧：鉴权 + 连接池 + numeric 项目/剧本 scope（与 [`super::owned_script_scope`] 对齐）。

use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope::{self, OwnedScriptScope};
use crate::state::AppState;

/// 仅校验 Bearer 并返回当前用户 UUID（不触发任何 DB scope 查询）。
pub fn require_authenticated_user(state: &AppState, headers: &HeaderMap) -> Result<Uuid, ApiError> {
    require_user_uuid(state, headers)
}

/// 当前用户 + DB 下，按 **numeric `project_id`** 解析项目主键（`app_project.id`）。
pub async fn require_owned_numeric_project_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, Uuid), ApiError> {
    let uid = require_user_uuid(state, headers)?;
    if project_numeric_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }
    let pool = state.require_pool()?;
    let project_id = scope::owned_project_id_by_numeric(pool, uid, project_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok((uid, pool, project_id))
}

/// 当前用户 + DB 下，按 **numeric `project_id` / `script_id`** 解析 [`OwnedScriptScope`]。
///
/// 与分散在 `production/workbench/*/common` 的旧实现等价：先校验正整数，再查库。
pub async fn require_owned_numeric_script_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, OwnedScriptScope), ApiError> {
    let uid = require_user_uuid(state, headers)?;
    if project_numeric_id <= 0 || script_numeric_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    let pool = state.require_pool()?;
    let scope_row = scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok((uid, pool, scope_row))
}
