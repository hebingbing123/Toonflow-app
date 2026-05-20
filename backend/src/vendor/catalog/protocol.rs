//! Vendor protocol and video-provider metadata from the static catalog.

use super::data::CATALOG;

/// How chat / multimodal text calls are executed for a catalog vendor.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum VendorProtocol {
    #[default]
    OpenAiCompatible,
    Anthropic,
    GeminiNative,
    /// Volcengine Ark (`https://ark.*.volces.com/api/v3`) — OpenAI-shaped HTTP.
    VolcengineArk,
    AzureOpenAi,
}

impl VendorProtocol {
    pub fn from_catalog_str(raw: &str) -> Self {
        match raw.trim().to_ascii_lowercase().as_str() {
            "anthropic" => Self::Anthropic,
            "gemini" | "gemini_native" => Self::GeminiNative,
            "volcengine" | "volcengine_ark" | "doubao" | "ark" => Self::VolcengineArk,
            "azure" | "azure_openai" => Self::AzureOpenAi,
            _ => Self::OpenAiCompatible,
        }
    }
}

/// Video backend slug for `VideoProvider::from_str`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CatalogVideoSlug {
    Runway,
    Pika,
    Kling,
    Doubao,
    Hunyuan,
    Minimax,
    OpenAi,
}

impl CatalogVideoSlug {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Runway => "runway",
            Self::Pika => "pika",
            Self::Kling => "kling",
            Self::Doubao => "doubao",
            Self::Hunyuan => "hunyuan",
            Self::Minimax => "minimax",
            Self::OpenAi => "openai",
        }
    }
}

pub(crate) fn vendor_protocol(vendor_id: i32) -> VendorProtocol {
    let Some(v) = CATALOG.vendors.iter().find(|v| v.id == vendor_id) else {
        return VendorProtocol::OpenAiCompatible;
    };
    v.protocol
        .as_deref()
        .map(VendorProtocol::from_catalog_str)
        .unwrap_or(VendorProtocol::OpenAiCompatible)
}

pub(crate) fn vendor_video_slug(vendor_id: i32) -> Option<CatalogVideoSlug> {
    let v = CATALOG.vendors.iter().find(|v| v.id == vendor_id)?;
    let raw = v.video_provider.as_deref()?;
    parse_video_slug(raw)
}

pub(crate) fn model_protocol(model_id: &str) -> VendorProtocol {
    let (vid_str, _) = model_id.split_once(':').unwrap_or((model_id, ""));
    let vendor_id: i32 = vid_str.parse().unwrap_or(0);
    vendor_protocol(vendor_id)
}

pub(crate) fn resolve_video_provider_slug(
    raw_vendor_id: &str,
    model_name: &str,
) -> Option<CatalogVideoSlug> {
    if let Ok(id) = raw_vendor_id.trim().parse::<i32>() {
        if let Some(slug) = vendor_video_slug(id) {
            return Some(slug);
        }
    }
    if let Some(slug) = parse_video_slug(raw_vendor_id) {
        return Some(slug);
    }
    if let Some(slug) = parse_video_slug(model_name) {
        return Some(slug);
    }
    None
}

fn parse_video_slug(raw: &str) -> Option<CatalogVideoSlug> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "runway" => Some(CatalogVideoSlug::Runway),
        "pika" => Some(CatalogVideoSlug::Pika),
        "kling" | "可灵" => Some(CatalogVideoSlug::Kling),
        "doubao" | "volcengine" | "seedance" | "byteplus" => Some(CatalogVideoSlug::Doubao),
        "hunyuan" | "tencent" | "混元" => Some(CatalogVideoSlug::Hunyuan),
        "minimax" | "hailuo" => Some(CatalogVideoSlug::Minimax),
        "openai" | "sora" => Some(CatalogVideoSlug::OpenAi),
        _ => None,
    }
}
