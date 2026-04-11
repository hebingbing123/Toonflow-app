//! Shared application state (DB pool, auth secret, LLM config, outbound HTTP, notify hub).

mod from_env;
mod memory_config;
mod notify_hub;
mod vendor_config;

use std::path::PathBuf;
use std::sync::Arc;

use sqlx::PgPool;
use tokio::sync::RwLock;

use crate::llm::LlmConfig;

pub use memory_config::MemoryConfig;
pub use notify_hub::WsNotifyHub;
pub use vendor_config::{VendorConfig, VendorConfigEntry};

/// 共享应用状态（数据库连接池、认证密钥、LLM 配置、出站 HTTP、通知中心）。
///
/// 在 Axum 处理函数中通过 `State<AppState>` 提取，包含所有跨请求共享的资源。
#[derive(Clone)]
pub struct AppState {
    /// PostgreSQL 连接池（未配置 DATABASE_URL 时为 None）。
    pub pool: Option<PgPool>,
    /// JWT 签名密钥（未配置 JWT_SECRET 时为 None）。
    pub jwt_secret: Option<Vec<u8>>,
    /// LLM 提供商配置（OpenAI 兼容 API）。
    pub llm: Option<LlmConfig>,
    /// 共享的 HTTP 客户端（用于调用外部 API）。
    pub http_client: reqwest::Client,
    /// WebSocket 通知中心（按用户广播任务更新）。
    pub notify: WsNotifyHub,
    /// 遗留 `o_setting` 内存/RAG 限制；在用户设置表存在前使用进程内存储。
    pub memory_config: Arc<RwLock<MemoryConfig>>,
    /// 遗留 `o_setting.switchAiDevTool`；可通过环境变量引导的进程本地覆盖。
    pub switch_ai_dev_tool: Arc<RwLock<String>>,
    /// 设置时，`asset.generate.*` Worker 将 PNG 保存到 `{dir}/{user_id}/{image_row_id}.png`，
    /// 并将 `app_asset_image.file_path` 设为此 API 的 `…/images/{id}/file` 路径。
    pub local_asset_image_dir: Option<PathBuf>,
    /// 设置时，艺术风格创建/更新可能将上传的 base64 封面保存到 `{dir}/{user_id}/{legacy_id}.{ext}`，
    /// 并通过 `GET …/art-styles/legacy/{id}/cover` 提供。
    pub local_art_style_cover_dir: Option<PathBuf>,
}

impl AppState {
    pub async fn from_env() -> Result<Self, sqlx::Error> {
        from_env::load().await
    }
}
