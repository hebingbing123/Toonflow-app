use serde_json::Value;
use sqlx::{types::Json as SqlxJson, PgPool};
use uuid::Uuid;

use crate::error::ApiError;

pub(crate) async fn resolve_owned_asset_id_for_project(
    pool: &PgPool,
    _uid: Uuid,
    project_id: Uuid,
    asset_numeric_id: i32,
) -> Result<Uuid, ApiError> {
    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest(
            "asset_numeric_id must be positive".into(),
        ));
    }
    let id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

pub(crate) async fn resolve_owned_asset_id_and_metadata_for_project(
    pool: &PgPool,
    _uid: Uuid,
    project_id: Uuid,
    asset_numeric_id: i32,
) -> Result<(Uuid, Value), ApiError> {
    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest(
            "asset_numeric_id must be positive".into(),
        ));
    }
    let row: Option<(Uuid, SqlxJson<Value>)> = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let (id, meta) = row.ok_or(ApiError::NotFound)?;
    Ok((id, meta.0))
}
