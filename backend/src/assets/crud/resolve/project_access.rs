use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// **404** if the UUID project is missing or not accessible by **`uid`** in workspace membership scope.
pub(crate) async fn ensure_owned_project_pk(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
) -> Result<(), ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM app_project p
          WHERE p.id = $1
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
    .bind(project_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if ok {
        Ok(())
    } else {
        Err(ApiError::NotFound)
    }
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
            if n <= 0 {
                return Err(ApiError::BadRequest(
                    "project_numeric_id must be positive".into(),
                ));
            }
            let resolved = ensure_owned_project_numeric_id(pool, uid, u).await?;
            if resolved != n {
                return Err(ApiError::BadRequest(
                    "Project UUID and numeric project id must refer to the same project".into(),
                ));
            }
            Ok(resolved)
        }
        (Some(u), None) => ensure_owned_project_numeric_id(pool, uid, u).await,
        (None, Some(n)) => {
            if n <= 0 {
                return Err(ApiError::BadRequest(
                    "project_numeric_id must be positive".into(),
                ));
            }
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
        (None, None) => Err(ApiError::BadRequest(
            "Provide project UUID (preferred) or legacy numeric project id".into(),
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
            if n <= 0 {
                return Err(ApiError::BadRequest(
                    "project_numeric_id must be positive".into(),
                ));
            }
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
                return Err(ApiError::BadRequest(
                    "Project UUID and numeric project id must refer to the same project".into(),
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
            if n <= 0 {
                return Err(ApiError::BadRequest(
                    "project_numeric_id must be positive".into(),
                ));
            }
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
        (None, None) => Err(ApiError::BadRequest(
            "Provide project UUID (preferred) or legacy numeric project id".into(),
        )),
    }
}
