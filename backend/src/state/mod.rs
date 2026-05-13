//! 共享应用状态（数据库连接池、认证密钥、LLM 配置、出站 HTTP、通知中心）。

mod from_env;
mod memory_config;
mod notify_hub;
mod vendor_config;

use std::path::PathBuf;
use std::sync::Arc;

use sqlx::PgPool;
use tokio::sync::RwLock;

use crate::error::ApiError;
use crate::http_kit::metrics::MetricsRegistry;
use crate::llm::LlmConfig;
use crate::metering::BillingConfig;

pub use memory_config::MemoryConfig;
pub use notify_hub::WsNotifyHub;
pub use vendor_config::{VendorConfig, VendorConfigEntry};

#[derive(Clone)]
pub struct AppState {
    pub pool: Option<PgPool>,
    pub jwt_secret: Option<Vec<u8>>,
    pub llm: Option<LlmConfig>,
    pub http_client: reqwest::Client,
    pub notify: WsNotifyHub,
    /// SQLite **`o_setting`** memory/RAG limits; in-process until a user settings table exists.
    pub memory_config: Arc<RwLock<MemoryConfig>>,
    /// SQLite-era **`o_setting.switchAiDevTool`**; process-local override with env bootstrap.
    pub switch_ai_dev_tool: Arc<RwLock<String>>,
    /// When set, **`asset.generate.*`** workers persist PNGs under **`{dir}/{user_id}/{image_row_id}.png`**
    /// and set **`app_asset_image.file_path`** to this API’s **`…/images/{id}/file`** path.
    pub local_asset_image_dir: Option<PathBuf>,
    /// When set, art-style create/patch may persist uploaded base64 covers under
    /// **`{dir}/{user_id}/{numeric_id}.{ext}`** and serve them via **`GET …/art-styles/numeric/{id}/cover`**.
    pub local_art_style_cover_dir: Option<PathBuf>,
    /// When set, **`video.export`** workers persist exported video files under
    /// **`{dir}/{user_id}/{job_id}.{ext}`** and serve them via **`GET /api/v1/jobs/{id}/file`**.
    pub local_video_export_dir: Option<PathBuf>,
    /// When set, **`voiceover.generate`** workers persist synthesized audio files under
    /// **`{dir}/{user_id}/{job_id}.mp3`** and serve them via **`GET /api/v1/jobs/{id}/file`**.
    pub local_voiceover_audio_dir: Option<PathBuf>,
    /// Metrics registry for request tracking and SLI monitoring
    pub metrics_registry: Arc<MetricsRegistry>,
    /// Billing configuration for workspace-scope billing (W8.2–W8.4)
    pub billing_config: BillingConfig,
}

impl AppState {
    pub async fn from_env() -> Result<Self, sqlx::Error> {
        from_env::load().await
    }

    pub fn require_pool(&self) -> Result<&PgPool, ApiError> {
        self.pool
            .as_ref()
            .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))
    }
}
