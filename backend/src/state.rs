use std::time::Duration;

use sqlx::postgres::PgPoolOptions;
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
        let pool = match std::env::var("DATABASE_URL") {
            Ok(url) => {
                tracing::info!("connecting database");
                Some(
                    PgPoolOptions::new()
                        .max_connections(10)
                        .connect(&url)
                        .await?,
                )
            }
            Err(_) => {
                tracing::info!(
                    "DATABASE_URL not set; readiness will report database as not_configured"
                );
                None
            }
        };

        let jwt_secret = std::env::var("SUPABASE_JWT_SECRET")
            .ok()
            .filter(|s| !s.is_empty())
            .map(|s| s.into_bytes());

        if jwt_secret.is_none() {
            tracing::warn!("SUPABASE_JWT_SECRET not set; GET /api/v1/me returns 503");
        }

        let llm = LlmConfig::from_env();
        if llm.is_none() {
            tracing::warn!(
                "OPENAI_API_KEY / LLM_API_KEY not set; agent.chat.send returns llm_not_configured"
            );
        }

        let http_client = reqwest::Client::builder()
            .connect_timeout(Duration::from_secs(30))
            .timeout(Duration::from_secs(180))
            .build()
            .unwrap_or_else(|e| {
                tracing::error!(%e, "reqwest client build failed; using default Client::new()");
                reqwest::Client::new()
            });

        Ok(Self {
            pool,
            jwt_secret,
            llm,
            http_client,
            notify: WsNotifyHub::new(),
        })
    }
}
