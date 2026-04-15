//! 视频生成提供商抽象层，支持 Runway、Pika 和 Kling。
//!
//! 每个提供商都有自己的 API 格式和认证方法。
//! 此模块为视频生成提供统一接口。

use serde::{Deserialize, Serialize};
use std::str::FromStr;
use std::time::Duration;

mod providers;

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

fn default_duration() -> u32 {
    5
}
fn default_resolution() -> String {
    "720p".to_string()
}
fn default_aspect_ratio() -> String {
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

/// Unified video provider client
pub struct VideoProviderClient {
    http: reqwest::Client,
}

impl VideoProviderClient {
    pub fn new() -> Self {
        Self {
            http: reqwest::Client::builder()
                .timeout(Duration::from_secs(120))
                .build()
                .unwrap_or_default(),
        }
    }

    /// Generate video using specified provider
    pub async fn generate_video(
        &self,
        req: &VideoGenerationRequest,
    ) -> anyhow::Result<VideoGenerationResponse> {
        self.generate_video_with_api_key(req, None).await
    }

    pub async fn generate_video_with_api_key(
        &self,
        req: &VideoGenerationRequest,
        api_key_override: Option<&str>,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = resolve_provider_api_key(req.provider, api_key_override)?;
        match req.provider {
            VideoProvider::Runway => self.generate_runway(req, &api_key).await,
            VideoProvider::Pika => self.generate_pika(req, &api_key).await,
            VideoProvider::Kling => self.generate_kling(req, &api_key).await,
        }
    }

    /// Poll video generation status
    pub async fn poll_generation(
        &self,
        provider: VideoProvider,
        task_id: &str,
    ) -> anyhow::Result<VideoGenerationResponse> {
        if !provider.is_configured() {
            return Err(anyhow::anyhow!(
                "{} API key not configured",
                provider.name()
            ));
        }

        match provider {
            VideoProvider::Runway => self.poll_runway(task_id).await,
            VideoProvider::Pika => self.poll_pika(task_id).await,
            VideoProvider::Kling => self.poll_kling(task_id).await,
        }
    }

    /// Export video
    pub async fn export_video(
        &self,
        req: &VideoExportRequest,
    ) -> anyhow::Result<VideoExportResponse> {
        // Export is typically done via internal processing or a specific provider
        // For now, we'll implement a placeholder that downloads and re-encodes
        tracing::info!(
            source_url = %req.source_url,
            format = %req.format,
            "Video export requested (placeholder implementation)"
        );

        Ok(VideoExportResponse {
            task_id: uuid::Uuid::new_v4().to_string(),
            status: VideoExportStatus::Completed,
            export_url: Some(req.source_url.clone()),
            error_message: None,
        })
    }
}

impl Default for VideoProviderClient {
    fn default() -> Self {
        Self::new()
    }
}

fn resolve_provider_api_key(
    provider: VideoProvider,
    api_key_override: Option<&str>,
) -> anyhow::Result<String> {
    if let Some(value) = api_key_override.map(str::trim).filter(|s| !s.is_empty()) {
        return Ok(value.to_string());
    }

    std::env::var(provider.api_key_env_var()).map_err(|_| {
        anyhow::anyhow!(
            "{} API key not configured (set {})",
            provider.name(),
            provider.api_key_env_var()
        )
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn video_provider_from_str() {
        assert_eq!("runway".parse::<VideoProvider>(), Ok(VideoProvider::Runway));
        assert_eq!("RUNWAY".parse::<VideoProvider>(), Ok(VideoProvider::Runway));
        assert_eq!("pika".parse::<VideoProvider>(), Ok(VideoProvider::Pika));
        assert_eq!("kling".parse::<VideoProvider>(), Ok(VideoProvider::Kling));
        assert_eq!("可灵".parse::<VideoProvider>(), Ok(VideoProvider::Kling));
        assert!("unknown".parse::<VideoProvider>().is_err());
    }

    #[test]
    fn video_provider_names() {
        assert_eq!(VideoProvider::Runway.name(), "Runway");
        assert_eq!(VideoProvider::Pika.name(), "Pika");
        assert_eq!(VideoProvider::Kling.name(), "Kling");
    }

    #[test]
    fn video_generation_status_as_str() {
        assert_eq!(VideoGenerationStatus::Queued.as_str(), "queued");
        assert_eq!(VideoGenerationStatus::Processing.as_str(), "processing");
        assert_eq!(VideoGenerationStatus::Completed.as_str(), "completed");
        assert_eq!(VideoGenerationStatus::Failed.as_str(), "failed");
    }

    #[test]
    fn video_generation_request_defaults() {
        let req = VideoGenerationRequest {
            provider: VideoProvider::Runway,
            model: "gen-2".to_string(),
            prompt: "Test".to_string(),
            negative_prompt: None,
            duration: default_duration(),
            resolution: default_resolution(),
            aspect_ratio: default_aspect_ratio(),
            image_url: None,
            seed: None,
        };
        assert_eq!(req.duration, 5);
        assert_eq!(req.resolution, "720p");
        assert_eq!(req.aspect_ratio, "16:9");
    }
}
