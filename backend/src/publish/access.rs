//! Project helpers for publish routes (`app_project.id` UUID scope).

use uuid::Uuid;

use crate::error::ApiError;

pub(crate) async fn script_belongs_to_project(
    pool: &sqlx::PgPool,
    script_id: Uuid,
    project_id: Uuid,
) -> Result<bool, ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_script
          WHERE id = $1 AND project_id = $2
        )
        "#,
    )
    .bind(script_id)
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(ok)
}

pub(crate) async fn profile_belongs_to_project(
    pool: &sqlx::PgPool,
    profile_id: Uuid,
    project_id: Uuid,
) -> Result<bool, ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_publish_profile
          WHERE id = $1 AND project_id = $2
        )
        "#,
    )
    .bind(profile_id)
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(ok)
}
