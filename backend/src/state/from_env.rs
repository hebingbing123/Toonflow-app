//! 从进程环境构建 `AppState`（Postgres 连接池、JWT 密钥、LLM、HTTP 客户端）。

use std::time::Duration;

use sqlx::postgres::PgPoolOptions;

use std::sync::Arc;

use tokio::sync::RwLock;

use super::{AppState, MemoryConfig, WsNotifyHub};
use crate::http_kit::metrics::MetricsRegistry;
use crate::llm::LlmConfig;
use crate::metering::BillingConfig;

const ENV_SWITCH_AI_DEV_TOOL: &str = "OPENFLOW_SWITCH_AI_DEV_TOOL";

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

    let local_asset_image_dir = std::env::var("OPENFLOW_LOCAL_ASSET_IMAGE_DIR")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(std::path::PathBuf::from);
    if local_asset_image_dir.is_some() {
        tracing::info!(
            "OPENFLOW_LOCAL_ASSET_IMAGE_DIR set; asset.generate workers will persist PNGs locally"
        );
    }
    let local_art_style_cover_dir = std::env::var("OPENFLOW_LOCAL_ART_STYLE_COVER_DIR")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(std::path::PathBuf::from);
    if local_art_style_cover_dir.is_some() {
        tracing::info!(
            "OPENFLOW_LOCAL_ART_STYLE_COVER_DIR set; art-style base64 covers will persist locally"
        );
    }
    let local_video_export_dir = std::env::var("OPENFLOW_LOCAL_VIDEO_EXPORT_DIR")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(std::path::PathBuf::from);
    if local_video_export_dir.is_some() {
        tracing::info!(
            "OPENFLOW_LOCAL_VIDEO_EXPORT_DIR set; video.export workers will persist video artifacts locally"
        );
    }
    let local_voiceover_audio_dir = std::env::var("OPENFLOW_LOCAL_VOICEOVER_AUDIO_DIR")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(std::path::PathBuf::from);
    if local_voiceover_audio_dir.is_some() {
        tracing::info!(
            "OPENFLOW_LOCAL_VOICEOVER_AUDIO_DIR set; voiceover.generate workers will persist audio artifacts locally"
        );
    }
    if std::env::var("OPENFLOW_LOCAL_WORKSPACE_SHARED_AUDIT_EXPORT_DIR")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .is_some()
    {
        tracing::info!(
            "OPENFLOW_LOCAL_WORKSPACE_SHARED_AUDIT_EXPORT_DIR set; settings.workspace_shared_audit.export workers will persist CSV/JSON under that root"
        );
    }
    if std::env::var("OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_BUCKET")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .is_some()
    {
        tracing::info!(
            "OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_BUCKET set; workspace shared audit export artifacts use S3 (multi-replica safe)"
        );
    }
    if std::env::var("OPENFLOW_ACCOUNT_EXPORT_S3_BUCKET")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .is_some()
    {
        tracing::info!(
            "OPENFLOW_ACCOUNT_EXPORT_S3_BUCKET set; settings.account.export artifacts use S3 (multi-replica safe)"
        );
    }
    if std::env::var("OPENFLOW_EXPORT_S3_ENDPOINT")
        .ok()
        .map(|s| !s.trim().is_empty())
        .unwrap_or(false)
    {
        tracing::info!("OPENFLOW_EXPORT_S3_ENDPOINT set; shared S3/MinIO endpoint override for export artifacts");
    }

    let billing_config = BillingConfig::from_env();
    if billing_config.workspace_billing_enabled {
        tracing::info!("Workspace-scope billing enabled (WORKSPACE_BILLING_ENABLED=true)");
    } else {
        tracing::info!("User-scope billing active (WORKSPACE_BILLING_ENABLED not set or false)");
    }

    tracing::info!(
        legacy_numeric_read = crate::legacy_numeric_id::legacy_numeric_read_enabled(),
        legacy_numeric_write = crate::legacy_numeric_id::legacy_numeric_write_enabled(),
        sunset = crate::legacy_numeric_id::LEGACY_NUMERIC_SUNSET,
        "numeric_id removal window policy (see docs/plans/tasks-http-api-cleanup.md H5·D)"
    );

    Ok(AppState {
        pool,
        jwt_secret,
        llm,
        http_client,
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new(switch_ai_dev_tool_from_env())),
        local_asset_image_dir,
        local_art_style_cover_dir,
        local_video_export_dir,
        local_voiceover_audio_dir,
        metrics_registry: Arc::new(MetricsRegistry::default()),
        billing_config,
    })
}
