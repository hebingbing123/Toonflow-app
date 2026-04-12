//! 用户归属下的项目 / 剧本解析，供 **HTTP 与 Harness** 共用（见 `docs/plans/backend-domain-layer-review.md` §4.1）。
//!
//! 与 [`crate::production_flow::resolve_owned_production_scope`] 的关系：后者额外返回 `script_content`；
//! 本模块仅解析 **UUID 级的 `project_id` / `script_id`**，用于「已附着 project 上下文下的某条剧本」鉴权。

use sqlx::PgPool;
use uuid::Uuid;

/// 当前用户拥有下的项目与剧本（`app_project` / `app_script` 行）。
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct OwnedScriptScope {
    pub project_id: Uuid,
    pub script_id: Uuid,
}

#[derive(Debug)]
pub enum ScopeError {
    /// 无匹配行（未拥有或 ID 不存在）。
    NotFound,
    Database(String),
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
