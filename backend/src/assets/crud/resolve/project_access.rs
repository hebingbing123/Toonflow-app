use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// **404** if the UUID project is missing or not owned by **`uid`**.
pub(crate) async fn ensure_owned_project_pk(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
) -> Result<(), ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"SELECT EXISTS (SELECT 1 FROM app_project WHERE id = $1 AND owner_user_id = $2)"#,
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

/// **404** if the project is missing or not owned; returns **`app_project.numeric_id`** for Electron-era payloads.
pub(crate) async fn ensure_owned_project_numeric_id(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
) -> Result<i32, ApiError> {
    let v: Option<i32> = sqlx::query_scalar(
        r#"SELECT p.numeric_id FROM app_project p WHERE p.id = $1 AND p.owner_user_id = $2"#,
    )
    .bind(project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    v.ok_or(ApiError::NotFound)
}
