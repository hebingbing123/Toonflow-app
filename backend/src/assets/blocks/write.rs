//! Upsert block index rows and optional PNG payload (rebuild plan P0-4).

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, ApiError};

use super::repository::AssetBlockRow;

pub struct AssetBlockWriteService;

impl AssetBlockWriteService {
    #[allow(clippy::too_many_arguments)]
    pub async fn create_block(
        pool: &PgPool,
        asset_id: Uuid,
        block_key: &str,
        dpi_tier: i16,
        width: i32,
        height: i32,
        png_bytes: Option<&[u8]>,
        local_root: Option<&std::path::Path>,
        owner_user_id: Uuid,
    ) -> Result<AssetBlockRow, ApiError> {
        let key = block_key.trim();
        if key.is_empty() {
            return Err(bad_request_i18n(
                "block_key must not be empty",
                "block_key 不能为空",
            ));
        }
        if !(1..=4).contains(&dpi_tier) {
            return Err(bad_request_i18n(
                "dpi_tier must be between 1 and 4",
                "dpi_tier 必须在 1 到 4 之间",
            ));
        }
        if width <= 0 || height <= 0 {
            return Err(bad_request_i18n(
                "width and height must be positive",
                "width 与 height 必须为正数",
            ));
        }

        let row = sqlx::query_as::<_, AssetBlockRow>(
            r#"
            INSERT INTO app_asset_block (asset_id, block_key, dpi_tier, storage_path, width, height)
            VALUES ($1, $2, $3, 'local', $4, $5)
            ON CONFLICT (asset_id, block_key, dpi_tier)
            DO UPDATE SET
              width = EXCLUDED.width,
              height = EXCLUDED.height,
              storage_path = 'local',
              updated_at = NOW()
            RETURNING id, asset_id, block_key, dpi_tier, storage_path, width, height
            "#,
        )
        .bind(asset_id)
        .bind(key)
        .bind(dpi_tier)
        .bind(width)
        .bind(height)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if let Some(bytes) = png_bytes {
            let Some(root) = local_root else {
                return Err(ApiError::DatabaseError(
                    "OPENFLOW_LOCAL_ASSET_IMAGE_DIR is not set".into(),
                ));
            };
            let path = super::service::AssetBlockService::resolve_local_block_path(
                root,
                owner_user_id,
                row.id,
            );
            if let Some(parent) = path.parent() {
                tokio::fs::create_dir_all(parent)
                    .await
                    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            }
            tokio::fs::write(&path, bytes)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }

        Ok(row)
    }
}
