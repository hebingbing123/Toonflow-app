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

/// Video generation request parameters
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoGenerationRequest {
    /// Provider to use
    pub provider: VideoProvider,
    /// Model identifier (provider-specific)
    pub model: String,
    /// Text prompt describing the video
    pub prompt: String,
    /// Optional negative prompt
    #[serde(skip_serializing_if = "Option::is_none")]
    pub negative_prompt: Option<String>,
    /// Duration in seconds (default: 5)
    #[serde(default = "default_duration")]
    pub duration: u32,
    /// Resolution preset (default: "720p")
    #[serde(default = "default_resolution")]
    pub resolution: String,
    /// Aspect ratio (default: "16:9")
    #[serde(default = "default_aspect_ratio")]
    pub aspect_ratio: String,
    /// Optional image URL for image-to-video generation
    #[serde(skip_serializing_if = "Option::is_none")]
    pub image_url: Option<String>,
    /// Optional seed for reproducibility
    #[serde(skip_serializing_if = "Option::is_none")]
    pub seed: Option<u64>,
}

pub(super) fn default_duration() -> u32 {
    5
}
pub(super) fn default_resolution() -> String {
    "720p".to_string()
}
pub(super) fn default_aspect_ratio() -> String {
    "16:9".to_string()
}

/// Video generation response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoGenerationResponse {
    /// Provider used
    pub provider: String,
    /// Model used
    pub model: String,
    /// Generation task ID for polling
    pub task_id: String,
    /// Current status
    pub status: VideoGenerationStatus,
    /// Video URL (when completed)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub video_url: Option<String>,
    /// Preview/thumbnail URL
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preview_url: Option<String>,
    /// Error message if failed
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
}

/// Video generation status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VideoGenerationStatus {
    Queued,
    Processing,
    Completed,
    Failed,
}

impl VideoGenerationStatus {
    #[allow(dead_code)]
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Queued => "queued",
            Self::Processing => "processing",
            Self::Completed => "completed",
            Self::Failed => "failed",
        }
    }
}

/// Video export request parameters
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoExportRequest {
    /// Source video URL
    pub source_url: String,
    /// Export format (mp4, mov, etc.)
    #[serde(default = "default_export_format")]
    pub format: String,
    /// Target resolution
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_resolution: Option<String>,
    /// Include audio
    #[serde(default = "default_true")]
    pub include_audio: bool,
}

fn default_export_format() -> String {
    "mp4".to_string()
}
fn default_true() -> bool {
    true
}

/// Video export response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoExportResponse {
    /// Export task ID
    pub task_id: String,
    /// Current status
    pub status: VideoExportStatus,
    /// Exported video URL
    #[serde(skip_serializing_if = "Option::is_none")]
    pub export_url: Option<String>,
    /// Error message if failed
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
}

/// Video export status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VideoExportStatus {
    Queued,
    Processing,
    Completed,
    Failed,
}

impl VideoExportStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Queued => "queued",
            Self::Processing => "processing",
            Self::Completed => "completed",
            Self::Failed => "failed",
        }
    }
}
