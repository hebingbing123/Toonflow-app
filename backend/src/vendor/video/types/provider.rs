use serde::{Deserialize, Serialize};
use std::str::FromStr;

/// Supported video generation providers
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VideoProvider {
    Runway,
    Pika,
    Kling,
    Doubao,
    Hunyuan,
    Minimax,
    OpenAi,
}

impl FromStr for VideoProvider {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_ascii_lowercase().as_str() {
            "runway" => Ok(Self::Runway),
            "pika" => Ok(Self::Pika),
            "kling" | "可灵" => Ok(Self::Kling),
            "doubao" | "volcengine" | "seedance" | "byteplus" => Ok(Self::Doubao),
            "hunyuan" | "tencent" | "混元" => Ok(Self::Hunyuan),
            "minimax" | "hailuo" => Ok(Self::Minimax),
            "openai" | "sora" => Ok(Self::OpenAi),
            _ => Err(()),
        }
    }
}

impl VideoProvider {
    pub fn from_catalog_slug(slug: crate::vendor::catalog::CatalogVideoSlug) -> Self {
        match slug {
            crate::vendor::catalog::CatalogVideoSlug::Runway => Self::Runway,
            crate::vendor::catalog::CatalogVideoSlug::Pika => Self::Pika,
            crate::vendor::catalog::CatalogVideoSlug::Kling => Self::Kling,
            crate::vendor::catalog::CatalogVideoSlug::Doubao => Self::Doubao,
            crate::vendor::catalog::CatalogVideoSlug::Hunyuan => Self::Hunyuan,
            crate::vendor::catalog::CatalogVideoSlug::Minimax => Self::Minimax,
            crate::vendor::catalog::CatalogVideoSlug::OpenAi => Self::OpenAi,
        }
    }
}

impl VideoProvider {
    /// Get the provider name
    pub fn name(&self) -> &'static str {
        match self {
            Self::Runway => "Runway",
            Self::Pika => "Pika",
            Self::Kling => "Kling",
            Self::Doubao => "Doubao Seedance",
            Self::Hunyuan => "Tencent Hunyuan",
            Self::Minimax => "MiniMax Hailuo",
            Self::OpenAi => "OpenAI Sora",
        }
    }

    /// Static catalog vendor ids that may hold credentials / `base_url` for this backend.
    pub fn catalog_vendor_ids(self) -> &'static [i32] {
        match self {
            Self::Runway => &[2],
            Self::Pika => &[3],
            Self::Kling => &[4],
            Self::Doubao => &[20, 18],
            Self::Hunyuan => &[21, 19],
            Self::Minimax => &[22, 13],
            Self::OpenAi => &[1],
        }
    }

    /// Get API base URL for the provider
    pub fn api_base(&self) -> &'static str {
        match self {
            Self::Runway => "https://api.dev.runwayml.com",
            Self::Pika => "https://queue.fal.run",
            Self::Kling => "https://api.klingai.com",
            Self::Doubao => "https://ark.cn-beijing.volces.com",
            Self::Hunyuan => "https://vclm.tencentcloudapi.com",
            Self::Minimax => "https://api.minimaxi.com",
            Self::OpenAi => "https://api.openai.com",
        }
    }

    /// Builtin API root (trailing slashes trimmed). Prefer [`super::endpoint::resolve_video_api_base`] for jobs.
    pub fn api_base_url(&self) -> String {
        self.api_base().trim_end_matches('/').to_string()
    }

    pub fn api_key_env_var(&self) -> &'static str {
        match self {
            Self::Runway => "RUNWAY_API_KEY",
            Self::Pika => "FAL_KEY",
            Self::Kling => "KLING_API_KEY",
            Self::Doubao => "VOLCENGINE_API_KEY",
            Self::Hunyuan => "HUNYUAN_API_KEY",
            Self::Minimax => "MINIMAX_API_KEY",
            Self::OpenAi => "OPENAI_API_KEY",
        }
    }

    /// Check if API key is configured via environment variable
    pub fn is_configured(&self) -> bool {
        std::env::var(self.api_key_env_var()).is_ok()
    }
}
