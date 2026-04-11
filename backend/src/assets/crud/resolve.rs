//! 资产 ID 解析辅助函数。
//!
//! 提供资产 UUID 解析功能，供 [`super::super::crud_images`] 和后台任务使用。
//! 支持通过遗留 ID 解析资产 UUID 并验证用户所有权。

use serde_json::Value;
use sqlx::{types::Json as SqlxJson, PgPool};
use uuid::Uuid;

use crate::error::ApiError;

pub(crate) async fn resolve_owned_asset_id(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<Uuid, ApiError> {
    let id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

/// Background worker: resolve **`app_asset.id`** by legacy ids and project owner.
pub async fn resolve_asset_id_for_job(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(owner_user_id)
    .bind(asset_legacy_id)
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

pub(crate) async fn resolve_owned_asset_id_and_metadata(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<(Uuid, Value), ApiError> {
    let row: Option<(Uuid, SqlxJson<Value>)> = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let (id, meta) = row.ok_or(ApiError::NotFound)?;
    Ok((id, meta.0))
}
