use std::time::Duration;

use super::types::{
    VideoExportRequest, VideoExportResponse, VideoExportStatus, VideoGenerationRequest,
    VideoGenerationResponse, VideoProvider,
};

/// Unified video provider client
pub struct VideoProviderClient {
    pub(super) http: reqwest::Client,
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
        validate_export_request(req)?;
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

fn validate_export_request(req: &VideoExportRequest) -> anyhow::Result<()> {
    let source_url = req.source_url.trim();
    if source_url.is_empty() {
        return Err(anyhow::anyhow!("source_url cannot be empty"));
    }
    let parsed =
        reqwest::Url::parse(source_url).map_err(|e| anyhow::anyhow!("invalid source_url: {e}"))?;
    match parsed.scheme() {
        "http" | "https" => {}
        other => {
            return Err(anyhow::anyhow!(
                "unsupported source_url scheme: {other} (expected http/https)"
            ));
        }
    }

    let format = req.format.trim().to_ascii_lowercase();
    if !matches!(format.as_str(), "mp4" | "mov" | "webm") {
        return Err(anyhow::anyhow!(
            "unsupported export format: {} (expected mp4/mov/webm)",
            req.format
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::validate_export_request;
    use crate::vendor::video::VideoExportRequest;

    #[test]
    fn validate_export_request_rejects_empty_source_url() {
        let req = VideoExportRequest {
            source_url: "   ".to_string(),
            format: "mp4".to_string(),
            target_resolution: None,
            include_audio: true,
        };
        let err = validate_export_request(&req).expect_err("should reject empty source_url");
        assert!(err.to_string().contains("source_url cannot be empty"));
    }

    #[test]
    fn validate_export_request_rejects_unsupported_format() {
        let req = VideoExportRequest {
            source_url: "https://example.com/video.mp4".to_string(),
            format: "avi".to_string(),
            target_resolution: None,
            include_audio: true,
        };
        let err = validate_export_request(&req).expect_err("should reject unsupported format");
        assert!(err.to_string().contains("unsupported export format"));
    }
}
