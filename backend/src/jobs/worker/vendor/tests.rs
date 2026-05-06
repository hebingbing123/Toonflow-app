use std::sync::Arc;

use tokio::sync::RwLock;

use super::super::JobRunError;
use super::llm_config::vendor_probe_llm_config;
use super::preview::clip_preview;
use super::resolve::{resolve_vendor_probe_targets, vendor_probe_credential_source};
use crate::state::AppState;
use crate::state::MemoryConfig;
use crate::state::WsNotifyHub;

fn test_state_without_llm() -> AppState {
    AppState {
        metrics_registry: Arc::new(crate::http_kit::metrics::MetricsRegistry::default()),
        pool: None,
        jwt_secret: None,
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
        local_video_export_dir: None,
        local_voiceover_audio_dir: None,
    }
}

#[test]
fn clip_preview_trims_and_ellipsizes() {
    assert_eq!(clip_preview("  ok  ", 8), "ok");
    assert_eq!(clip_preview("abcdef", 4), "abcd...");
}

#[test]
fn resolve_vendor_probe_targets_expands_catalog_aliases() {
    let (vendor, resolved_vendor_id, candidates) = resolve_vendor_probe_targets("1");
    assert!(
        vendor.is_some(),
        "numeric id should resolve into vendor catalog"
    );
    assert_eq!(resolved_vendor_id, "openai");
    assert_eq!(candidates, vec!["1", "openai"]);
}

#[test]
fn resolve_vendor_probe_targets_normalizes_unknown_vendor_ids() {
    let (vendor, resolved_vendor_id, candidates) =
        resolve_vendor_probe_targets("  CUSTOM-ENDPOINT  ");
    assert!(vendor.is_none());
    assert_eq!(resolved_vendor_id, "custom-endpoint");
    assert_eq!(candidates, vec!["CUSTOM-ENDPOINT", "custom-endpoint"]);
}

#[test]
fn vendor_probe_credential_source_prefers_stored_credentials() {
    assert_eq!(
        vendor_probe_credential_source("text", true),
        "stored_vendor_credential"
    );
    assert_eq!(
        vendor_probe_credential_source("image", false),
        "server_llm_env"
    );
    assert_eq!(
        vendor_probe_credential_source("video", false),
        "provider_env"
    );
}

#[test]
fn vendor_probe_llm_config_without_state_llm_returns_clear_error() {
    let state = test_state_without_llm();
    let err = match vendor_probe_llm_config(&state, None, "gpt-4o-mini") {
        Ok(_) => panic!("text/image probe should require llm config or stored secret"),
        Err(err) => err,
    };

    match err {
        JobRunError::Failed(message) => {
            assert!(
                message.contains("OPENAI_API_KEY") || message.contains("LLM_API_KEY"),
                "unexpected message: {message}"
            );
        }
        JobRunError::FailedStructured { message, .. } => {
            panic!("unexpected structured failure: {message}");
        }
        JobRunError::Cancelled => panic!("unexpected cancellation"),
    }
}
