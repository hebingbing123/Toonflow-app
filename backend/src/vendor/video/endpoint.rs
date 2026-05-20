//! Per-vendor video API base URL (Settings → catalog default → env test override → builtin).

use std::collections::HashMap;

use crate::state::VendorConfig;
use crate::vendor::catalog::llm_endpoint::catalog_vendor_endpoint_meta;

use crate::vendor::user_credentials::expand_vendor_id_candidates;

use crate::vendor::gateway::is_aggregation_gateway;

use super::auth::{resolve_video_auth, VideoProviderAuth, VideoProviderCredentials};
use super::VideoProvider;

/// How to talk to the resolved API root (official vendor API vs unified OpenAI-shaped gateway).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VideoApiRouting {
    /// Native paths documented for [`VideoProvider`] (Runway tasks, Kling JWT, TC3, fal queue, …).
    NativeVendor,
    /// `POST/GET /v1/videos` — for OneAPI / New API / other aggregators.
    OpenAiCompatible,
}

/// Effective API root + resolved auth for one video submit/poll chain.
#[derive(Clone)]
pub struct VideoProviderCall {
    pub auth: VideoProviderAuth,
    pub api_base: String,
    pub routing: VideoApiRouting,
    /// Logical provider (model routing, job payload); HTTP path follows [`Self::routing`].
    pub provider: VideoProvider,
}

/// Candidate `app_vendor_credential.vendor_id` values for a video job.
pub fn video_vendor_id_candidates(
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
) -> Vec<String> {
    let mut out = Vec::new();
    if let Some(raw) = catalog_model_id.map(str::trim).filter(|s| !s.is_empty()) {
        if let Some((vid, _)) = raw.split_once(':') {
            for c in expand_vendor_id_candidates(vid) {
                if !out.contains(&c) {
                    out.push(c);
                }
            }
        }
        for c in expand_vendor_id_candidates(raw) {
            if !out.contains(&c) {
                out.push(c);
            }
        }
    }
    for id in provider.catalog_vendor_ids() {
        for c in expand_vendor_id_candidates(&id.to_string()) {
            if !out.contains(&c) {
                out.push(c);
            }
        }
    }
    out
}

impl VideoProviderCall {
    pub fn build(
        provider: VideoProvider,
        credentials: Option<&VideoProviderCredentials>,
        catalog_model_id: Option<&str>,
        vendor_config: Option<&VendorConfig>,
    ) -> anyhow::Result<Self> {
        let api_base = resolve_video_api_base(provider, catalog_model_id, vendor_config);
        let routing =
            resolve_video_api_routing(provider, catalog_model_id, vendor_config, &api_base);
        let auth = resolve_video_auth(provider, credentials, &api_base, routing)?;
        Ok(Self {
            auth,
            api_base,
            routing,
            provider,
        })
    }
}

/// User `base_url` → catalog `default_base_url` → [`VideoProvider::api_base_url`] (test env + builtin).
pub fn resolve_video_api_base(
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
    vendor_config: Option<&VendorConfig>,
) -> String {
    let candidates = video_vendor_id_candidates(provider, catalog_model_id);

    if let Some(config) = vendor_config {
        for vid in &candidates {
            if let Some(entry) = config.get_vendor(vid) {
                if let Some(url) = base_url_from_settings(&entry.settings) {
                    return url;
                }
            }
        }
    }

    if let Some(url) = test_override_api_base() {
        return url;
    }

    for vid in &candidates {
        if let Ok(numeric) = vid.parse::<i32>() {
            let (catalog_default, _) = catalog_vendor_endpoint_meta(numeric);
            if let Some(url) = catalog_default {
                return url;
            }
        }
    }

    provider.api_base().trim_end_matches('/').to_string()
}

fn test_override_api_base() -> Option<String> {
    let raw = std::env::var("OPENFLOW_TEST_VIDEO_API_BASE").ok()?;
    let trimmed = raw.trim().trim_end_matches('/');
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

/// Third-party platform (OneAPI / New API / 硅基流动): user sets a unified `base_url` that is
/// not the vendor's official host → use OpenAI-compatible `/v1/...` only.
fn resolve_video_api_routing(
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
    vendor_config: Option<&VendorConfig>,
    resolved_base: &str,
) -> VideoApiRouting {
    let candidates = video_vendor_id_candidates(provider, catalog_model_id);
    let user_base = vendor_config.and_then(|config| {
        candidates
            .iter()
            .find_map(|vid| config.get_vendor(vid))
            .and_then(|entry| base_url_from_settings(&entry.settings))
    });
    if let Some(user_base) = user_base {
        if is_aggregation_gateway(&user_base, provider.api_base()) {
            return VideoApiRouting::OpenAiCompatible;
        }
    }
    let _ = resolved_base;
    VideoApiRouting::NativeVendor
}

fn base_url_from_settings(settings: &HashMap<String, String>) -> Option<String> {
    let raw = settings
        .get("base_url")
        .or_else(|| settings.get("baseUrl"))?;
    let trimmed = raw.trim().trim_end_matches('/');
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

/// Host header and endpoint root for TC3 signing from an HTTPS base URL.
#[allow(dead_code)] // kept for future TC3/canonical signing helpers
pub fn api_base_host_and_root(api_base: &str) -> (String, String) {
    let trimmed = api_base.trim().trim_end_matches('/');
    if let Ok(url) = reqwest::Url::parse(trimmed) {
        if let Some(host) = url.host_str() {
            let host_with_port = match url.port() {
                Some(port) => format!("{host}:{port}"),
                None => host.to_string(),
            };
            return (host_with_port, trimmed.to_string());
        }
    }
    (trimmed.to_string(), trimmed.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::{VendorConfig, VendorConfigEntry};

    #[test]
    fn user_base_url_wins_over_catalog_default() {
        let mut config = VendorConfig::default();
        config.vendors.insert(
            "20".to_string(),
            VendorConfigEntry {
                vendor_id: "20".to_string(),
                display_name: None,
                enabled: true,
                selected_models: vec![],
                settings: [(
                    "base_url".to_string(),
                    "https://proxy.example/volc".to_string(),
                )]
                .into_iter()
                .collect(),
            },
        );
        let base = resolve_video_api_base(
            VideoProvider::Doubao,
            Some("20:doubao-seedance-1-0-pro"),
            Some(&config),
        );
        assert_eq!(base, "https://proxy.example/volc");
    }

    #[test]
    fn catalog_default_used_when_no_user_override() {
        let base = resolve_video_api_base(
            VideoProvider::Doubao,
            Some("20:doubao-seedance-1-0-pro"),
            None,
        );
        assert_eq!(base, "https://ark.cn-beijing.volces.com");
    }

    #[test]
    fn kling_builtin_when_no_catalog_override() {
        let base = resolve_video_api_base(VideoProvider::Kling, None, None);
        assert_eq!(base, "https://api.klingai.com");
    }

    #[test]
    fn aggregation_routing_when_user_base_differs_from_official() {
        let mut config = VendorConfig::default();
        config.vendors.insert(
            "4".to_string(),
            VendorConfigEntry {
                vendor_id: "4".to_string(),
                display_name: None,
                enabled: true,
                selected_models: vec![],
                settings: [(
                    "base_url".to_string(),
                    "https://api.oneapi.example/v1".to_string(),
                )]
                .into_iter()
                .collect(),
            },
        );
        let routing = resolve_video_api_routing(
            VideoProvider::Kling,
            Some("4:kling-v1"),
            Some(&config),
            "https://api.oneapi.example/v1",
        );
        assert_eq!(routing, VideoApiRouting::OpenAiCompatible);
    }

    #[test]
    fn native_routing_when_no_user_base_override() {
        let routing = resolve_video_api_routing(
            VideoProvider::Kling,
            Some("4:kling-v1"),
            None,
            "https://api.klingai.com",
        );
        assert_eq!(routing, VideoApiRouting::NativeVendor);
    }
}
