use serde::{Deserialize, Serialize};

use super::provider::VideoProvider;

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

pub(crate) fn default_duration() -> u32 {
    5
}
pub(crate) fn default_resolution() -> String {
    "720p".to_string()
}
pub(crate) fn default_aspect_ratio() -> String {
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
