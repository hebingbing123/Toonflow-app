//! Axum handler 侧：鉴权 + 连接池 + numeric 项目/剧本 scope（与 [`super::owned_script_scope`] 对齐）。

use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::production::flow_data;
use crate::scope::{self, OwnedScriptInProject, OwnedScriptScope};
use crate::state::AppState;

fn require_authenticated_pool<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
) -> Result<(Uuid, &'a PgPool), ApiError> {
    let uid = require_user_uuid(state, headers)?;
    let pool = state.require_pool()?;
    Ok((uid, pool))
}

async fn owned_project_id_by_numeric_checked(
    pool: &PgPool,
    uid: Uuid,
    project_numeric_id: i32,
) -> Result<Uuid, ApiError> {
    crate::legacy_numeric_id::ensure_legacy_numeric_read_allowed()?;
    scope::owned_project_id_by_numeric(pool, uid, project_numeric_id)
        .await
        .map_err(|e| e.into_api_error())
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
        return Err(bad_request_i18n(
            "projectId must be a positive integer",
            "projectId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    let project_id = owned_project_id_by_numeric_checked(pool, uid, project_numeric_id).await?;
    Ok((uid, pool, project_id))
}

/// 与 [`require_owned_numeric_project_scope`] 相同，但仅返回 handler 常用的 `pool + project_id`。
pub async fn require_owned_numeric_project_scope_id<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid), ApiError> {
    let (_uid, pool, project_id) =
        require_owned_numeric_project_scope(state, headers, project_numeric_id).await?;
    Ok((pool, project_id))
}

/// 当前用户 + DB 下，按 **numeric `project_id`** 解析项目主键，
/// 并使用统一的 workspace 成员权限校验（`require_project_workspace_member_scope`）。
pub async fn require_project_read_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, Uuid), ApiError> {
    if project_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "projectId must be a positive integer",
            "projectId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;

    // First resolve the project UUID from numeric ID
    let project_id = owned_project_id_by_numeric_checked(pool, uid, project_numeric_id).await?;

    // Use unified workspace member read permission check
    let _scope = crate::projects::routes::common::require_project_workspace_member_scope(
        state, uid, project_id,
    )
    .await?;

    Ok((uid, pool, project_id))
}

/// 与 [`require_project_read_scope`] 相同，但仅返回 handler 常用的 `pool + project_id`。
pub async fn require_project_read_scope_id<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid), ApiError> {
    let (_uid, pool, project_id) =
        require_project_read_scope(state, headers, project_numeric_id).await?;
    Ok((pool, project_id))
}

/// 当前用户 + DB 下，按 **`project_uuid | project_id`** 解析项目 scope，
/// 并返回 UUID 与 legacy numeric id，使用统一的项目写权限校验。
pub async fn require_project_write_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: Option<i32>,
    project_uuid: Option<Uuid>,
) -> Result<(Uuid, &'a PgPool, Uuid, i32), ApiError> {
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    if let Some(project_id) = project_uuid {
        let _scope =
            crate::projects::routes::common::require_project_write_scope(state, uid, project_id)
                .await?;
        let project_numeric_id = sqlx::query_scalar::<_, i32>(
            r#"
            SELECT p.numeric_id
            FROM app_project p
            WHERE p.id = $1
              AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $2
              )
            "#,
        )
        .bind(project_id)
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .ok_or(ApiError::NotFound)?;
        return Ok((uid, pool, project_id, project_numeric_id));
    }
    let project_numeric_id = project_numeric_id.ok_or_else(|| {
        bad_request_i18n(
            "projectId or projectUuid is required",
            "必须提供 projectId 或 projectUuid",
        )
    })?;
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    let project_id = owned_project_id_by_numeric_checked(pool, uid, project_numeric_id).await?;
    let _scope =
        crate::projects::routes::common::require_project_write_scope(state, uid, project_id)
            .await?;
    Ok((uid, pool, project_id, project_numeric_id))
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
        return Err(bad_request_i18n(
            "projectId and scriptId must be positive integers",
            "projectId 和 scriptId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    let scope_row = scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok((uid, pool, scope_row))
}

/// 与 [`require_owned_numeric_script_scope`] 相同，但仅返回 handler 实际常用的 `pool + scope`。
pub async fn require_owned_numeric_script_scope_row<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(&'a PgPool, OwnedScriptScope), ApiError> {
    let (_uid, pool, scope_row) =
        require_owned_numeric_script_scope(state, headers, project_numeric_id, script_numeric_id)
            .await?;
    Ok((pool, scope_row))
}

/// 与 [`require_owned_numeric_script_scope`] 相同，但仅返回常用的 `uid + pool + script_id`。
pub async fn require_owned_numeric_script_scope_ids<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, Uuid), ApiError> {
    let (uid, pool, scope_row) =
        require_owned_numeric_script_scope(state, headers, project_numeric_id, script_numeric_id)
            .await?;
    Ok((uid, pool, scope_row.script_id))
}

/// 与 [`require_owned_numeric_script_scope`] 相同，但仅返回常用的 `uid + pool`。
pub async fn require_owned_numeric_script_scope_user_pool<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool), ApiError> {
    let (uid, pool, _script_id) = require_owned_numeric_script_scope_ids(
        state,
        headers,
        project_numeric_id,
        script_numeric_id,
    )
    .await?;
    Ok((uid, pool))
}

/// 与 [`require_owned_numeric_script_scope`] 相同，但仅用于校验 scope 存在性（不返回值）。
pub async fn require_owned_numeric_script_access(
    state: &AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(), ApiError> {
    let (_uid, _pool, _scope_row) =
        require_owned_numeric_script_scope(state, headers, project_numeric_id, script_numeric_id)
            .await?;
    Ok(())
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
        return Err(bad_request_i18n(
            "projectId, scriptId, and storyboardId must be positive integers",
            "projectId、scriptId 和 storyboardId 必须是正整数",
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
        return Err(bad_request_i18n(
            &format!("projectId and {second_field_name} must be positive integers"),
            &format!("projectId 和 {second_field_name} 必须是正整数"),
        ));
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

/// 与 [`require_owned_numeric_production_episodes_scope`] 相同，但仅返回 `pool + project/script scope`。
pub async fn require_owned_numeric_production_episodes_scope_row<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    episodes_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid, Uuid, Option<String>), ApiError> {
    let (_uid, pool, project_id, script_id, script_content) =
        require_owned_numeric_production_episodes_scope(
            state,
            headers,
            project_numeric_id,
            episodes_numeric_id,
        )
        .await?;
    Ok((pool, project_id, script_id, script_content))
}

/// 当前用户 + DB 下，按 **`project_uuid | project_id`** + **numeric `episodes_id`**
/// 解析 production flow scope；优先使用稳定的 `app_project.id`。
pub async fn require_owned_production_episodes_scope_ref_row<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: Option<i32>,
    project_uuid: Option<Uuid>,
    episodes_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid, Uuid, Option<String>), ApiError> {
    if episodes_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "episodesId must be a positive integer",
            "episodesId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    if let Some(project_id) = project_uuid {
        let (project_id, script_id, script_content) =
            flow_data::resolve_owned_production_scope_by_project_id(
                pool,
                uid,
                project_id,
                episodes_numeric_id,
            )
            .await?;
        return Ok((pool, project_id, script_id, script_content));
    }
    let project_numeric_id = project_numeric_id.ok_or_else(|| {
        bad_request_i18n(
            "projectId or projectUuid is required",
            "必须提供 projectId 或 projectUuid",
        )
    })?;
    let (_uid, pool, project_id, script_id, script_content) =
        require_owned_numeric_production_episodes_scope(
            state,
            headers,
            project_numeric_id,
            episodes_numeric_id,
        )
        .await?;
    Ok((pool, project_id, script_id, script_content))
}

/// 当前用户 + DB 下，按 **numeric `project_id` / `script_id` / `storyboard_id`** 解析分镜主键，
/// 并使用统一的 workspace 成员权限校验（`require_project_write_scope`）。
pub async fn require_storyboard_write_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid), ApiError> {
    if project_numeric_id <= 0 || script_numeric_id <= 0 || storyboard_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "projectId, scriptId, and storyboardId must be positive integers",
            "projectId、scriptId 和 storyboardId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;

    // First resolve the project UUID from numeric ID
    let project_id = owned_project_id_by_numeric_checked(pool, uid, project_numeric_id).await?;

    // Use unified workspace member write permission check
    let _scope =
        crate::projects::routes::common::require_project_write_scope(state, uid, project_id)
            .await?;

    // Now resolve the storyboard UUID
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

/// 当前用户 + DB 下，按 **`project_uuid | project_id`** + numeric
/// `script_id/storyboard_id` 解析分镜主键，并使用统一的项目写权限校验。
pub async fn require_storyboard_write_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid), ApiError> {
    if script_numeric_id <= 0 || storyboard_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "scriptId and storyboardId must be positive integers",
            "scriptId 和 storyboardId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    if let Some(project_id) = project_uuid {
        let _scope =
            crate::projects::routes::common::require_project_write_scope(state, uid, project_id)
                .await?;
        let storyboard_row = scope::owned_storyboard_in_project_script_scope(
            pool,
            uid,
            project_id,
            script_numeric_id,
            storyboard_numeric_id,
        )
        .await
        .map_err(|e| e.into_api_error())?;
        return Ok((pool, storyboard_row.storyboard_id));
    }
    let project_numeric_id = project_numeric_id.ok_or_else(|| {
        bad_request_i18n(
            "projectId or projectUuid is required",
            "必须提供 projectId 或 projectUuid",
        )
    })?;
    require_storyboard_write_scope(
        state,
        headers,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await
}

/// 当前用户 + DB 下，按 **numeric `project_id` / `script_id` / `storyboard_id`** 解析分镜主键，
/// 并使用统一的 workspace 成员权限校验（`require_project_workspace_member_scope`）。
pub async fn require_storyboard_read_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid), ApiError> {
    if project_numeric_id <= 0 || script_numeric_id <= 0 || storyboard_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "projectId, scriptId, and storyboardId must be positive integers",
            "projectId、scriptId 和 storyboardId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;

    // First resolve the project UUID from numeric ID
    let project_id = owned_project_id_by_numeric_checked(pool, uid, project_numeric_id).await?;

    // Use unified workspace member read permission check
    let _scope = crate::projects::routes::common::require_project_workspace_member_scope(
        state, uid, project_id,
    )
    .await?;

    // Now resolve the storyboard UUID
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

/// 当前用户 + DB 下，按 **numeric `project_id` / `script_id`** 解析剧本 scope，
/// 并使用统一的 workspace 成员权限校验（`require_project_write_scope`）。
pub async fn require_script_write_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, OwnedScriptScope), ApiError> {
    if project_numeric_id <= 0 || script_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "projectId and scriptId must be positive integers",
            "projectId 和 scriptId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;

    // First resolve the project UUID from numeric ID
    let project_id = owned_project_id_by_numeric_checked(pool, uid, project_numeric_id).await?;

    // Use unified workspace member write permission check
    let _scope =
        crate::projects::routes::common::require_project_write_scope(state, uid, project_id)
            .await?;

    // Now resolve the script scope
    let scope_row = scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    Ok((uid, pool, scope_row))
}

/// 当前用户 + DB 下，按 **numeric `project_id` / `script_id`** 解析剧本 scope，
/// 并使用统一的 workspace 成员权限校验（`require_project_workspace_member_scope`）。
pub async fn require_script_read_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, OwnedScriptScope), ApiError> {
    if project_numeric_id <= 0 || script_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "projectId and scriptId must be positive integers",
            "projectId 和 scriptId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;

    // First resolve the project UUID from numeric ID
    let project_id = owned_project_id_by_numeric_checked(pool, uid, project_numeric_id).await?;

    // Use unified workspace member read permission check
    let _scope = crate::projects::routes::common::require_project_workspace_member_scope(
        state, uid, project_id,
    )
    .await?;

    // Now resolve the script scope
    let scope_row = scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    Ok((uid, pool, scope_row))
}

/// 当前用户 + DB 下，按 **`project_uuid | project_id`** + numeric `script_id`
/// 解析剧本 scope，并使用统一的 workspace 成员读权限校验。
pub async fn require_script_read_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, OwnedScriptInProject), ApiError> {
    if script_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "scriptId must be a positive integer",
            "scriptId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    if let Some(project_id) = project_uuid {
        let _scope = crate::projects::routes::common::require_project_workspace_member_scope(
            state, uid, project_id,
        )
        .await?;
        let scope_row = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
            .await
            .map_err(|e| e.into_api_error())?;
        return Ok((uid, pool, scope_row));
    }
    let project_numeric_id = project_numeric_id.ok_or_else(|| {
        bad_request_i18n(
            "projectId or projectUuid is required",
            "必须提供 projectId 或 projectUuid",
        )
    })?;
    let (uid, pool, scope_row) =
        require_script_read_scope(state, headers, project_numeric_id, script_numeric_id).await?;
    Ok((
        uid,
        pool,
        OwnedScriptInProject {
            project_id: scope_row.project_id,
            project_numeric_id,
            script_id: scope_row.script_id,
        },
    ))
}

/// 当前用户 + DB 下，按 **`project_uuid | project_id`** + numeric `script_id`
/// 解析剧本 scope，并使用统一的项目写权限校验。
pub async fn require_script_write_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_numeric_id: i32,
) -> Result<(Uuid, &'a PgPool, OwnedScriptInProject), ApiError> {
    if script_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "scriptId must be a positive integer",
            "scriptId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    if let Some(project_id) = project_uuid {
        let _scope =
            crate::projects::routes::common::require_project_write_scope(state, uid, project_id)
                .await?;
        let scope_row = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
            .await
            .map_err(|e| e.into_api_error())?;
        return Ok((uid, pool, scope_row));
    }
    let project_numeric_id = project_numeric_id.ok_or_else(|| {
        bad_request_i18n(
            "projectId or projectUuid is required",
            "必须提供 projectId 或 projectUuid",
        )
    })?;
    let (uid, pool, scope_row) =
        require_script_write_scope(state, headers, project_numeric_id, script_numeric_id).await?;
    Ok((
        uid,
        pool,
        OwnedScriptInProject {
            project_id: scope_row.project_id,
            project_numeric_id,
            script_id: scope_row.script_id,
        },
    ))
}

/// 当前用户 + DB 下，按 **`project_uuid | project_id`** + numeric
/// `script_id/storyboard_id` 解析分镜主键，并使用统一的项目读权限校验。
pub async fn require_storyboard_read_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_numeric_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(&'a PgPool, Uuid), ApiError> {
    if script_numeric_id <= 0 || storyboard_numeric_id <= 0 {
        return Err(bad_request_i18n(
            "scriptId and storyboardId must be positive integers",
            "scriptId 和 storyboardId 必须是正整数",
        ));
    }
    let (uid, pool) = require_authenticated_pool(state, headers)?;
    if let Some(project_id) = project_uuid {
        let _scope = crate::projects::routes::common::require_project_workspace_member_scope(
            state, uid, project_id,
        )
        .await?;
        let storyboard_row = scope::owned_storyboard_in_project_script_scope(
            pool,
            uid,
            project_id,
            script_numeric_id,
            storyboard_numeric_id,
        )
        .await
        .map_err(|e| e.into_api_error())?;
        return Ok((pool, storyboard_row.storyboard_id));
    }
    let project_numeric_id = project_numeric_id.ok_or_else(|| {
        bad_request_i18n(
            "projectId or projectUuid is required",
            "必须提供 projectId 或 projectUuid",
        )
    })?;
    require_storyboard_read_scope(
        state,
        headers,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await
}
