//! 与 [`super::super::crud_images`] 和后台任务共享的辅助函数。
//!
//! 资产 ID 解析（UUID 项目段）与元数据解析；队列侧仍可按 **`project_numeric_id`** 解析（见 **`resolve_asset_id_for_job`**）。

use serde_json::Value;
use sqlx::{types::Json as SqlxJson, PgPool};
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

pub(crate) async fn resolve_owned_asset_id_for_project(
    pool: &PgPool,
    uid: Uuid,
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
          AND p.owner_user_id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

/// Background worker: resolve **`app_asset.id`** by legacy ids and project owner.
pub async fn resolve_asset_id_for_job(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    asset_numeric_id: i32,
) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.numeric_id = $1
          AND p.owner_user_id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(project_numeric_id)
    .bind(owner_user_id)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
}

/// Next **`sort_index`** for a new **`app_asset_image`** row (append to history).
pub async fn next_asset_image_sort_index(
    pool: &PgPool,
    asset_id: Uuid,
) -> Result<i32, sqlx::Error> {
    let max: Option<i32> =
        sqlx::query_scalar(r#"SELECT MAX(sort_index) FROM app_asset_image WHERE asset_id = $1"#)
            .bind(asset_id)
            .fetch_one(pool)
            .await?;
    Ok(max.map_or(0, |m| m.saturating_add(1)))
}

pub(crate) async fn resolve_owned_asset_id_and_metadata_for_project(
    pool: &PgPool,
    uid: Uuid,
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
          AND p.owner_user_id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let (id, meta) = row.ok_or(ApiError::NotFound)?;
    Ok((id, meta.0))
}
