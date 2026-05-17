use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, validate_positive, ApiError};
use crate::legacy_numeric_id::ensure_legacy_numeric_read_allowed;
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope, ProjectAccessScope,
};
use crate::state::AppState;

/// Validates workspace member read access to a project using unified permission helpers.
/// Returns `ProjectAccessScope` for further permission checks if needed.
pub(crate) async fn require_asset_project_read_scope(
    state: &AppState,
    uid: Uuid,
    project_id: Uuid,
) -> Result<ProjectAccessScope, ApiError> {
    require_project_workspace_member_scope(state, uid, project_id).await
}

/// Validates workspace member write access to a project using unified permission helpers.
/// Returns `ProjectAccessScope` for further permission checks if needed.
pub(crate) async fn require_asset_project_write_scope(
    state: &AppState,
    uid: Uuid,
    project_id: Uuid,
) -> Result<ProjectAccessScope, ApiError> {
    require_project_write_scope(state, uid, project_id).await
}

/// **404** if the project is missing or inaccessible; returns **`app_project.numeric_id`** for Electron-era payloads.
pub(crate) async fn ensure_owned_project_numeric_id(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
) -> Result<i32, ApiError> {
    let v: Option<i32> = sqlx::query_scalar(
        r#"
        SELECT p.numeric_id
        FROM app_project p
        WHERE p.id = $1
          AND p.archived_at IS NULL
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    v.ok_or(ApiError::NotFound)
}

/// Resolves **`app_project.numeric_id`** when the client sends **UUID** and/or legacy **numeric** id.
///
/// Used by HTTP handlers that still key `app_agent_memory` / jobs by **`numeric_id`** while exposing
/// **`app_project.id`** on newer clients. Prefer UUID; if both are set they must agree.
pub(crate) async fn resolve_owned_project_numeric_from_uuid_or_legacy_id(
    pool: &PgPool,
    uid: Uuid,
    project_uuid: Option<Uuid>,
    project_numeric_id: Option<i32>,
) -> Result<i32, ApiError> {
    match (project_uuid, project_numeric_id) {
        (Some(u), Some(n)) => {
            validate_positive(n, "project_numeric_id")?;
            let resolved = ensure_owned_project_numeric_id(pool, uid, u).await?;
            if resolved != n {
                return Err(bad_request_i18n(
                    "Project UUID and numeric project id must refer to the same project",
                    "project UUID 和 numeric project id 必须指向同一个项目",
                ));
            }
            Ok(resolved)
        }
        (Some(u), None) => ensure_owned_project_numeric_id(pool, uid, u).await,
        (None, Some(n)) => {
            ensure_legacy_numeric_read_allowed()?;
            validate_positive(n, "project_numeric_id")?;
            let ok: bool = sqlx::query_scalar(
                r#"
                SELECT EXISTS(
                  SELECT 1
                  FROM app_project p
                  WHERE p.numeric_id = $1
                    AND p.archived_at IS NULL
                    AND EXISTS (
                      SELECT 1
                      FROM app_workspace_member wm
                      WHERE wm.workspace_id = p.workspace_id
                        AND wm.user_id = $2
                    )
                )
                "#,
            )
            .bind(n)
            .bind(uid)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            if !ok {
                return Err(ApiError::NotFound);
            }
            Ok(n)
        }
        (None, None) => Err(bad_request_i18n(
            "Provide project UUID (preferred) or legacy numeric project id",
            "请提供 project UUID（推荐）或旧版 numeric project id",
        )),
    }
}

/// Like [`resolve_owned_project_numeric_from_uuid_or_legacy_id`] but also returns **`app_project.id`** (UUID)
/// and **`app_project.workspace_id`** for workspace-scoped Harness / REST alignment.
pub(crate) async fn resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
    pool: &PgPool,
    uid: Uuid,
    project_uuid: Option<Uuid>,
    project_numeric_id: Option<i32>,
) -> Result<(Uuid, i32, Uuid), ApiError> {
    match (project_uuid, project_numeric_id) {
        (Some(u), Some(n)) => {
            validate_positive(n, "project_numeric_id")?;
            let row: Option<(Uuid, i32, Uuid)> = sqlx::query_as(
                r#"
                SELECT p.id, p.numeric_id, p.workspace_id
                FROM app_project p
                WHERE p.id = $1
                  AND p.archived_at IS NULL
                  AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $2
                  )
                "#,
            )
            .bind(u)
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            let (id, num, workspace_id) = row.ok_or(ApiError::NotFound)?;
            if num != n {
                return Err(bad_request_i18n(
                    "Project UUID and numeric project id must refer to the same project",
                    "project UUID 和 numeric project id 必须指向同一个项目",
                ));
            }
            Ok((id, num, workspace_id))
        }
        (Some(u), None) => {
            let row: Option<(Uuid, i32, Uuid)> = sqlx::query_as(
                r#"
                SELECT p.id, p.numeric_id, p.workspace_id
                FROM app_project p
                WHERE p.id = $1
                  AND p.archived_at IS NULL
                  AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $2
                  )
                "#,
            )
            .bind(u)
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            row.ok_or(ApiError::NotFound)
        }
        (None, Some(n)) => {
            ensure_legacy_numeric_read_allowed()?;
            validate_positive(n, "project_numeric_id")?;
            let row: Option<(Uuid, i32, Uuid)> = sqlx::query_as(
                r#"
                SELECT p.id, p.numeric_id, p.workspace_id
                FROM app_project p
                WHERE p.numeric_id = $1
                  AND p.archived_at IS NULL
                  AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $2
                  )
                "#,
            )
            .bind(n)
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            row.ok_or(ApiError::NotFound)
        }
        (None, None) => Err(bad_request_i18n(
            "Provide project UUID (preferred) or legacy numeric project id",
            "请提供 project UUID（推荐）或旧版 numeric project id",
        )),
    }
}
