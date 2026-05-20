//! Detect third-party **aggregation platforms** (OneAPI / New API / 硅基流动等)
//! vs direct calls to a vendor's official API host.

use super::video::VideoProvider;

/// User points Settings `base_url` at a **unified gateway** (OpenAI-compatible `/v1/...`)
/// instead of the vendor's official host — use standard protocol + model name only.
pub fn is_aggregation_gateway(resolved_base: &str, official_base: &str) -> bool {
    match (
        normalize_host_port(resolved_base),
        normalize_host_port(official_base),
    ) {
        (Some(a), Some(b)) => a != b,
        _ => true,
    }
}

pub fn is_aggregation_gateway_for_provider(provider: VideoProvider, resolved_base: &str) -> bool {
    is_aggregation_gateway(resolved_base, provider.api_base())
}

/// DashScope Wan native paths only work on official DashScope hosts, not on `/v1` gateways.
pub fn is_volcengine_ark_official_host(base_url: &str) -> bool {
    base_url.trim().to_ascii_lowercase().contains("volces.com")
}

pub fn is_gemini_official_host(base_url: &str) -> bool {
    base_url
        .trim()
        .to_ascii_lowercase()
        .contains("generativelanguage.googleapis.com")
}

pub fn is_dashscope_official_host(base_url: &str) -> bool {
    let lower = base_url.trim().to_ascii_lowercase();
    lower.contains("dashscope.aliyuncs.com")
        || lower.contains("dashscope-intl.aliyuncs.com")
        || lower.contains("dashscope-us.aliyuncs.com")
}

fn normalize_host_port(base_url: &str) -> Option<String> {
    let trimmed = base_url.trim();
    if trimmed.is_empty() {
        return None;
    }
    let with_scheme = if trimmed.contains("://") {
        trimmed.to_string()
    } else {
        format!("https://{trimmed}")
    };
    let url = reqwest::Url::parse(&with_scheme).ok()?;
    let host = url.host_str()?;
    Some(match url.port() {
        Some(port) => format!("{host}:{port}"),
        None => host.to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn siliconflow_base_is_aggregation_vs_ark_official() {
        assert!(is_aggregation_gateway(
            "https://api.siliconflow.cn/v1",
            "https://ark.cn-beijing.volces.com"
        ));
    }

    #[test]
    fn official_ark_host_is_not_aggregation() {
        assert!(!is_aggregation_gateway(
            "https://ark.cn-beijing.volces.com",
            "https://ark.cn-beijing.volces.com"
        ));
    }

    #[test]
    fn oneapi_style_openai_base_is_aggregation_for_kling() {
        assert!(is_aggregation_gateway_for_provider(
            VideoProvider::Kling,
            "https://my-oneapi.example.com/v1"
        ));
    }

    #[test]
    fn dashscope_compatible_mode_is_not_official_for_wan() {
        assert!(!is_dashscope_official_host("https://api.siliconflow.cn/v1"));
        assert!(is_dashscope_official_host(
            "https://dashscope.aliyuncs.com/compatible-mode/v1"
        ));
    }
}
