//! Shared application state (DB pool, auth secret, LLM config, outbound HTTP, notify hub).

mod from_env;
mod memory_config;
mod vendor_config;

use std::sync::Arc;

use sqlx::PgPool;
use tokio::sync::RwLock;

use crate::llm::LlmConfig;
use crate::notify_hub::WsNotifyHub;

pub use memory_config::MemoryConfig;
pub use vendor_config::{VendorConfig, VendorConfigEntry};

#[derive(Clone)]
pub struct AppState {
    pub pool: Option<PgPool>,
    pub jwt_secret: Option<Vec<u8>>,
    pub llm: Option<LlmConfig>,
    pub http_client: reqwest::Client,
    pub notify: WsNotifyHub,
    /// Legacy **`o_setting`** memory/RAG limits; in-process until a user settings table exists.
    pub memory_config: Arc<RwLock<MemoryConfig>>,
}

impl AppState {
    pub async fn from_env() -> Result<Self, sqlx::Error> {
        from_env::load().await
    }
}
