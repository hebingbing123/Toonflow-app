//! Block asset delivery service (rebuild plan P0-4).

use std::path::{Path, PathBuf};

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, ApiError};

use super::repository::{AssetBlockRepository, AssetBlockRow};

pub struct AssetBlockService;

impl AssetBlockService {
    /// Resolves the best DPI tier ≤ requested for a block.
    pub fn resolve_dpi_tier(device_pixel_ratio: f64) -> i16 {
        device_pixel_ratio.ceil().clamp(1.0, 4.0) as i16
    }

    pub async fn get_block_for_delivery(
        pool: &PgPool,
        asset_id: Uuid,
        block_key: &str,
        dpi: Option<i16>,
    ) -> Result<AssetBlockRow, ApiError> {
        let key = block_key.trim();
        if key.is_empty() {
            return Err(bad_request_i18n(
                "block_key must not be empty",
                "block_key 不能为空",
            ));
        }
        let requested = dpi
            .map(|d| d.clamp(1, 4))
            .unwrap_or_else(|| Self::resolve_dpi_tier(1.0));
        if let Some(row) = AssetBlockRepository::find_block(pool, asset_id, key, requested).await? {
            return Ok(row);
        }
        // Fallback to 1x when exact tier missing.
        if requested != 1 {
            if let Some(row) = AssetBlockRepository::find_block(pool, asset_id, key, 1).await? {
                return Ok(row);
            }
        }
        Err(ApiError::NotFound)
    }

    pub fn resolve_local_block_path(local_root: &Path, user_id: Uuid, block_id: Uuid) -> PathBuf {
        local_root
            .join(user_id.to_string())
            .join("blocks")
            .join(format!("{block_id}.png"))
    }
}
