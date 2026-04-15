//! 用户归属下的项目 / 剧本解析，供 **HTTP 与 Harness** 共用（见 `docs/plans/backend-domain-layer-review.md` §4.1）。
//!
//! 与 [`crate::production::flow_data::resolve_owned_production_scope`] 的关系：后者额外返回 `script_content`；
//! 本模块解析 **UUID 级的 `project_id` / `script_id`**；REST 常见 **`project_id` = `app_project.id`** 时用
//! [`owned_script_in_project`]，Electron 风格 **numeric project id** 时用 [`owned_script_scope`]；
//! 分镜按 **numeric_id** 落在项目下时用 [`owned_storyboard_in_project`]；
//! **numeric project + numeric script + numeric storyboard** 时用 [`owned_storyboard_in_script_scope`]；
//! 仅 **`app_project.numeric_id`** 时用 [`owned_project_id_by_numeric`]。

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// 当前用户拥有下的项目与剧本（`app_project` / `app_script` 行）。
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct OwnedScriptScope {
    pub project_id: Uuid,
    pub script_id: Uuid,
}

/// 与 [`OwnedScriptScope`] 相同语义，但项目以 **`app_project.id`（UUID）** 标识，并带上 **`app_project.numeric_id`**。
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct OwnedScriptInProject {
    pub project_id: Uuid,
    pub project_numeric_id: i32,
    pub script_id: Uuid,
}

/// 用户在项目 **`app_project.id`** 下对某条分镜（**`app_storyboard.numeric_id`**）的归属。
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct OwnedStoryboardInProject {
    pub storyboard_id: Uuid,
}

/// 用户在 **numeric 项目 + numeric 剧本** 下对某条分镜（**`app_storyboard.numeric_id`**）的分镜主键（`app_storyboard.id`）。
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct OwnedStoryboardInScript {
    pub storyboard_id: Uuid,
}

#[derive(Debug)]
pub enum ScopeError {
    /// 无匹配行（未拥有或 ID 不存在）。
    NotFound,
    Database(String),
}

impl ScopeError {
    #[must_use]
    pub fn into_api_error(self) -> ApiError {
        match self {
            ScopeError::NotFound => ApiError::NotFound,
            ScopeError::Database(msg) => ApiError::DatabaseError(msg),
        }
    }
}

/// 解析 `owner_user_id` 拥有的项目主键（**`app_project.id`**），按 **`app_project.numeric_id`**。
pub async fn owned_project_id_by_numeric(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
) -> Result<Uuid, ScopeError> {
    if project_numeric_id <= 0 {
        return Err(ScopeError::NotFound);
    }
    sqlx::query_scalar(
        r#"
        SELECT p.id
        FROM app_project p
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ScopeError::Database(e.to_string()))?
    .ok_or(ScopeError::NotFound)
}

/// 解析 `owner_user_id` 在 `project_numeric_id` 下对 `script_numeric_id` 的剧本 scope。
pub async fn owned_script_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<OwnedScriptScope, ScopeError> {
    sqlx::query_as::<_, OwnedScriptScope>(
        r#"
        SELECT p.id AS project_id, s.id AS script_id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND s.numeric_id = $3
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ScopeError::Database(e.to_string()))?
    .ok_or(ScopeError::NotFound)
}

/// 解析 `owner_user_id` 在 **`project_id`（`app_project.id`）** 下对 `script_numeric_id` 的剧本 scope。
pub async fn owned_script_in_project(
    pool: &PgPool,
    user_id: Uuid,
    project_id: Uuid,
    script_numeric_id: i32,
) -> Result<OwnedScriptInProject, ScopeError> {
    sqlx::query_as::<_, OwnedScriptInProject>(
        r#"
        SELECT
          p.id AS project_id,
          p.numeric_id AS project_numeric_id,
          s.id AS script_id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.id = $2
          AND s.numeric_id = $3
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ScopeError::Database(e.to_string()))?
    .ok_or(ScopeError::NotFound)
}

/// 解析 `owner_user_id` 在 **`project_numeric_id` + `script_numeric_id`** 下对 **`storyboard_numeric_id`** 的分镜行（`app_storyboard.id`）。
pub async fn owned_storyboard_in_script_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<OwnedStoryboardInScript, ScopeError> {
    let scope_row =
        owned_script_scope(pool, user_id, project_numeric_id, script_numeric_id).await?;
    sqlx::query_as::<_, OwnedStoryboardInScript>(
        r#"
        SELECT sb.id AS storyboard_id
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.numeric_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(storyboard_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ScopeError::Database(e.to_string()))?
    .ok_or(ScopeError::NotFound)
}

/// 解析 `owner_user_id` 在 **`project_id`** 下对 **`storyboard_numeric_id`** 的分镜行（`app_storyboard.id`）。
pub async fn owned_storyboard_in_project(
    pool: &PgPool,
    user_id: Uuid,
    project_id: Uuid,
    storyboard_numeric_id: i32,
) -> Result<OwnedStoryboardInProject, ScopeError> {
    sqlx::query_as::<_, OwnedStoryboardInProject>(
        r#"
        SELECT sb.id AS storyboard_id
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.id = $2
          AND sb.numeric_id = $3
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(storyboard_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ScopeError::Database(e.to_string()))?
    .ok_or(ScopeError::NotFound)
}
