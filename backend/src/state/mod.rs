//! Shared application state (DB pool, auth secret, LLM config, outbound HTTP, notify hub).

mod from_env;

use sqlx::PgPool;

use crate::llm::LlmConfig;
use crate::notify_hub::WsNotifyHub;

#[derive(Clone)]
pub struct AppState {
    pub pool: Option<PgPool>,
    pub jwt_secret: Option<Vec<u8>>,
    pub llm: Option<LlmConfig>,
    pub http_client: reqwest::Client,
    pub notify: WsNotifyHub,
}

impl AppState {
    pub async fn from_env() -> Result<Self, sqlx::Error> {
        from_env::load().await
    }
}
