use std::time::Duration;

use super::endpoint::VideoProviderCall as Call;
pub use super::endpoint::{VideoApiRouting, VideoProviderCall};
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

    pub async fn generate_video(
        &self,
        req: &VideoGenerationRequest,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let call = Call::build(req.provider, None, None, None)?;
        self.generate_video_with_call(req, &call).await
    }

    pub async fn generate_video_with_call(
        &self,
        req: &VideoGenerationRequest,
        call: &Call,
    ) -> anyhow::Result<VideoGenerationResponse> {
        if call.routing == VideoApiRouting::OpenAiCompatible {
            return self.generate_openai_video(req, call).await;
        }
        match call.provider {
            VideoProvider::Runway => self.generate_runway(req, call).await,
            VideoProvider::Pika => self.generate_pika(req, call).await,
            VideoProvider::Kling => self.generate_kling(req, call).await,
            VideoProvider::Doubao => self.generate_doubao(req, call).await,
            VideoProvider::Hunyuan => self.generate_hunyuan(req, call).await,
            VideoProvider::Minimax => self.generate_minimax(req, call).await,
            VideoProvider::OpenAi => self.generate_openai_video(req, call).await,
        }
    }

    /// Credentials only — API base from catalog / builtin (no Settings `base_url`).
    pub async fn generate_video_with_credentials(
        &self,
        req: &VideoGenerationRequest,
        creds: Option<&super::auth::VideoProviderCredentials>,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let call = Call::build(req.provider, creds, None, None)?;
        self.generate_video_with_call(req, &call).await
    }

    pub async fn generate_video_with_api_key(
        &self,
        req: &VideoGenerationRequest,
        api_key_override: Option<&str>,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let creds = api_key_override.map(|k| super::auth::VideoProviderCredentials {
            api_key: Some(k.to_string()),
            api_secret: None,
        });
        self.generate_video_with_credentials(req, creds.as_ref())
            .await
    }

    pub async fn poll_generation(
        &self,
        provider: VideoProvider,
        task_id: &str,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let call = Call::build(provider, None, None, None)?;
        self.poll_generation_with_call(provider, task_id, &call)
            .await
    }

    pub async fn poll_generation_with_call(
        &self,
        _provider: VideoProvider,
        task_id: &str,
        call: &Call,
    ) -> anyhow::Result<VideoGenerationResponse> {
        if call.routing == VideoApiRouting::OpenAiCompatible {
            return self.poll_openai_video(task_id, call).await;
        }
        match call.provider {
            VideoProvider::Runway => self.poll_runway(task_id, call).await,
            VideoProvider::Pika => self.poll_pika(task_id, call).await,
            VideoProvider::Kling => self.poll_kling(task_id, call).await,
            VideoProvider::Doubao => self.poll_doubao(task_id, call).await,
            VideoProvider::Hunyuan => self.poll_hunyuan(task_id, call).await,
            VideoProvider::Minimax => self.poll_minimax(task_id, call).await,
            VideoProvider::OpenAi => self.poll_openai_video(task_id, call).await,
        }
    }

    pub async fn poll_generation_with_credentials(
        &self,
        provider: VideoProvider,
        task_id: &str,
        creds: Option<&super::auth::VideoProviderCredentials>,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let call = Call::build(provider, creds, None, None)?;
        self.poll_generation_with_call(provider, task_id, &call)
            .await
    }

    pub async fn poll_generation_with_api_key(
        &self,
        provider: VideoProvider,
        task_id: &str,
        api_key_override: Option<&str>,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let creds = api_key_override.map(|k| super::auth::VideoProviderCredentials {
            api_key: Some(k.to_string()),
            api_secret: None,
        });
        self.poll_generation_with_credentials(provider, task_id, creds.as_ref())
            .await
    }

    pub async fn export_video(
        &self,
        req: &VideoExportRequest,
    ) -> anyhow::Result<VideoExportResponse> {
        validate_export_request(req)?;
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
