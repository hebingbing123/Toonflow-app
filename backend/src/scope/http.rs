//! Axum handler 侧：鉴权 + 连接池 + numeric 项目/剧本 scope（与 [`super::owned_script_scope`] 对齐）。

use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::production::flow_data;
use crate::scope::{self, OwnedScriptScope};
use crate::state::AppState;

fn require_authenticated_pool<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
) -> Result<(Uuid, &'a PgPool), ApiError> {
    let uid = require_user_uuid(state, headers)?;
    let pool = state.require_pool()?;
    Ok((uid, pool))
}

/// 仅校验 Bearer 并返回当前用户 UUID（不触发任何 DB scope 查询）。
pub fn require_authenticated_user(state: &AppState, headers: &HeaderMap) -> Result<Uuid, ApiError> {
    require_user_uuid(state, headers)
}

/// 仅校验 Bearer，忽略用户 id（适用于只需要鉴权、不使用 uid 的 handler）。
pub fn require_authenticated(state: &AppState, headers: &HeaderMap) -> Result<(), ApiError> {
    require_user_uuid(state, headers)?;
    Ok(())
}

/// 当前用户 + DB 下，按 **numeric `project_id`** 解析项目主键（`app_project.id`）。
pub async fn require_owned_numeric_project_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, Uuid), ApiError> {
    if project_numeric_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
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
    if project_numeric_id <= 0 || script_numeric_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    let scope_row = scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok((uid, pool, scope_row))
}

/// 当前用户 + DB 下，按 **numeric `project_id` / `script_id` / `storyboard_id`** 解析分镜主键（`app_storyboard.id`）。
pub async fn require_owned_numeric_storyboard_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid), ApiError> {
    if project_numeric_id <= 0 || script_numeric_id <= 0 || storyboard_numeric_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and storyboardId must be positive integers".into(),
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    let storyboard_row = scope::owned_storyboard_in_script_scope(
        pool,
        uid,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await
    .map_err(|e| e.into_api_error())?;
    Ok((pool, storyboard_row.storyboard_id))
}

async fn require_owned_numeric_production_scope_inner<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
    second_field_name: &str,
) -> Result<(Uuid, &'a PgPool, Uuid, Uuid, Option<String>), ApiError> {
    if project_numeric_id <= 0 || script_numeric_id <= 0 {
        return Err(ApiError::BadRequest(format!(
            "projectId and {second_field_name} must be positive integers"
        )));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    let (project_id, script_id, script_content) =
        flow_data::resolve_owned_production_scope(pool, uid, project_numeric_id, script_numeric_id)
            .await?;
    Ok((uid, pool, project_id, script_id, script_content))
}

/// 当前用户 + DB 下，按 **numeric `project_id` / `script_id`** 解析 production flow scope。
///
/// 返回 `(uid, pool, project_uuid, script_uuid, script_content)`，用于复用
/// `resolve_owned_production_scope` 逻辑，避免 handler 重复拼装。
pub async fn require_owned_numeric_production_script_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, Uuid, Uuid, Option<String>), ApiError> {
    require_owned_numeric_production_scope_inner(
        state,
        headers,
        project_numeric_id,
        script_numeric_id,
        "scriptId",
    )
    .await
}

/// 与 [`require_owned_numeric_production_script_scope`] 相同，但保持 `episodesId` 错误字段名兼容。
pub async fn require_owned_numeric_production_episodes_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    episodes_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, Uuid, Uuid, Option<String>), ApiError> {
    require_owned_numeric_production_scope_inner(
        state,
        headers,
        project_numeric_id,
        episodes_numeric_id,
        "episodesId",
    )
    .await
}
