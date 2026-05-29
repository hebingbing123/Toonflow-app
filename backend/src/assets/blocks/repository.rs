//! Block-level asset index repository (rebuild plan P0-4 / P0-5 pilot).

use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, Clone, sqlx::FromRow, Serialize)]
pub struct AssetBlockRow {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub block_key: String,
    pub dpi_tier: i16,
    pub storage_path: String,
    pub width: i32,
    pub height: i32,
}

pub struct AssetBlockRepository;

impl AssetBlockRepository {
    pub async fn find_block(
        pool: &PgPool,
        asset_id: Uuid,
        block_key: &str,
        dpi_tier: i16,
    ) -> Result<Option<AssetBlockRow>, ApiError> {
        sqlx::query_as::<_, AssetBlockRow>(
            r#"
            SELECT id, asset_id, block_key, dpi_tier, storage_path, width, height
            FROM app_asset_block
            WHERE asset_id = $1 AND block_key = $2 AND dpi_tier = $3
            "#,
        )
        .bind(asset_id)
        .bind(block_key)
        .bind(dpi_tier)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
    }

    pub async fn list_blocks_for_asset(
        pool: &PgPool,
        asset_id: Uuid,
    ) -> Result<Vec<AssetBlockRow>, ApiError> {
        sqlx::query_as::<_, AssetBlockRow>(
            r#"
            SELECT id, asset_id, block_key, dpi_tier, storage_path, width, height
            FROM app_asset_block
            WHERE asset_id = $1
            ORDER BY block_key ASC, dpi_tier ASC
            "#,
        )
        .bind(asset_id)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
    }
}
