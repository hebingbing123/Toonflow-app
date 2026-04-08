//! Wire `AppState` from process environment (Postgres pool, JWT secret, LLM, HTTP client).

use std::time::Duration;

use sqlx::postgres::PgPoolOptions;

use std::sync::Arc;

use tokio::sync::RwLock;

use super::{AppState, MemoryConfig};
use crate::llm::LlmConfig;
use crate::notify_hub::WsNotifyHub;

const ENV_SWITCH_AI_DEV_TOOL: &str = "TOONFLOW_SWITCH_AI_DEV_TOOL";

fn switch_ai_dev_tool_from_env() -> String {
    match std::env::var(ENV_SWITCH_AI_DEV_TOOL) {
        Ok(s) if s.trim() == "1" => "1".into(),
        _ => "0".into(),
    }
}

pub(super) async fn load() -> Result<AppState, sqlx::Error> {
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

    let local_asset_image_dir = std::env::var("TOONFLOW_LOCAL_ASSET_IMAGE_DIR")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(std::path::PathBuf::from);
    if local_asset_image_dir.is_some() {
        tracing::info!(
            "TOONFLOW_LOCAL_ASSET_IMAGE_DIR set; asset.generate workers will persist PNGs locally"
        );
    }
    let local_art_style_cover_dir = std::env::var("TOONFLOW_LOCAL_ART_STYLE_COVER_DIR")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(std::path::PathBuf::from);
    if local_art_style_cover_dir.is_some() {
        tracing::info!(
            "TOONFLOW_LOCAL_ART_STYLE_COVER_DIR set; art-style base64 covers will persist locally"
        );
    }

    Ok(AppState {
        pool,
        jwt_secret,
        llm,
        http_client,
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        switch_ai_dev_tool: Arc::new(RwLock::new(switch_ai_dev_tool_from_env())),
        local_asset_image_dir,
        local_art_style_cover_dir,
    })
}
