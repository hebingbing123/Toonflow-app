//! Resolve OpenAI-compatible `base_url` + API key for a catalog vendor.

use std::collections::HashMap;

use crate::llm::LlmConfig;

use super::data::CATALOG;
use super::protocol::{model_protocol, vendor_protocol};

const LOCAL_PLACEHOLDER_API_KEY: &str = "ollama";

/// Catalog defaults and flags for a vendor numeric id.
pub(crate) fn catalog_vendor_endpoint_meta(vendor_id: i32) -> (Option<String>, bool) {
    let Some(v) = CATALOG.vendors.iter().find(|v| v.id == vendor_id) else {
        return (None, false);
    };
    (
        v.default_base_url
            .as_ref()
            .map(|s| s.trim().trim_end_matches('/').to_string())
            .filter(|s| !s.is_empty()),
        v.api_key_optional,
    )
}

fn env_openai_base_url() -> String {
    std::env::var("OPENAI_BASE_URL")
        .unwrap_or_else(|_| "https://api.openai.com/v1".to_string())
        .trim()
        .trim_end_matches('/')
        .to_string()
}

/// Effective base URL: user `base_url` setting → catalog default → `OPENAI_BASE_URL`.
pub(crate) fn resolve_base_url(
    vendor_id: i32,
    user_settings: Option<&HashMap<String, String>>,
) -> String {
    if let Some(settings) = user_settings {
        if let Some(raw) = settings.get("base_url").or_else(|| settings.get("baseUrl")) {
            let trimmed = raw.trim().trim_end_matches('/');
            if !trimmed.is_empty() {
                return trimmed.to_string();
            }
        }
    }
    let (catalog_default, _) = catalog_vendor_endpoint_meta(vendor_id);
    catalog_default.unwrap_or_else(env_openai_base_url)
}

/// Build [`LlmConfig`] for chat / multimodal / image (OpenAI-shaped) calls.
pub(crate) fn build_llm_config(
    vendor_id: i32,
    model_name: String,
    user_settings: Option<&HashMap<String, String>>,
    stored_api_key: Option<String>,
    server_llm: Option<&LlmConfig>,
) -> Result<LlmConfig, String> {
    let base_url = resolve_base_url(vendor_id, user_settings);
    let (_, api_key_optional) = catalog_vendor_endpoint_meta(vendor_id);
    let protocol = if model_name.contains(':') {
        model_protocol(&model_name)
    } else {
        vendor_protocol(vendor_id)
    };

    if let Some(key) = stored_api_key.filter(|s| !s.trim().is_empty()) {
        return Ok(LlmConfig {
            api_key: key,
            base_url,
            model: model_name,
            protocol,
        });
    }

    if api_key_optional {
        return Ok(LlmConfig {
            api_key: LOCAL_PLACEHOLDER_API_KEY.to_string(),
            base_url,
            model: model_name,
            protocol,
        });
    }

    let Some(server) = server_llm else {
        return Err(
            "LLM API key required for this vendor — add one under Settings → Model providers"
                .into(),
        );
    };

    Ok(LlmConfig {
        api_key: server.api_key.clone(),
        base_url,
        model: model_name,
        protocol,
    })
}

/// Back-compat alias.
pub(crate) fn build_openai_compatible_config(
    vendor_id: i32,
    model_name: String,
    user_settings: Option<&HashMap<String, String>>,
    stored_api_key: Option<String>,
    server_llm: Option<&LlmConfig>,
) -> Result<LlmConfig, String> {
    build_llm_config(
        vendor_id,
        model_name,
        user_settings,
        stored_api_key,
        server_llm,
    )
}
