use serde::{Deserialize, Serialize};
use std::str::FromStr;

/// Supported video generation providers
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VideoProvider {
    Runway,
    Pika,
    Kling,
}

impl FromStr for VideoProvider {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_ascii_lowercase().as_str() {
            "runway" => Ok(Self::Runway),
            "pika" => Ok(Self::Pika),
            "kling" | "可灵" => Ok(Self::Kling),
            _ => Err(()),
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
        }
    }

    /// Get API base URL for the provider
    pub fn api_base(&self) -> &'static str {
        match self {
            Self::Runway => "https://api.runwayml.com",
            Self::Pika => "https://api.pika.art",
            Self::Kling => "https://api.klingai.com",
        }
    }

    pub fn api_key_env_var(&self) -> &'static str {
        match self {
            Self::Runway => "RUNWAY_API_KEY",
            Self::Pika => "PIKA_API_KEY",
            Self::Kling => "KLING_API_KEY",
        }
    }

    /// Check if API key is configured via environment variable
    pub fn is_configured(&self) -> bool {
        std::env::var(self.api_key_env_var()).is_ok()
    }
}
