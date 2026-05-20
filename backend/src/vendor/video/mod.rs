//! 视频生成提供商抽象层，支持 Runway、Pika 和 Kling。
//!
//! 每个提供商都有自己的 API 格式和认证方法。
//! 此模块为视频生成提供统一接口。

pub(crate) mod auth;
mod client;
pub(crate) mod credentials;
#[cfg(test)]
pub(crate) mod doc_fixtures;
pub(crate) mod endpoint;
mod providers;
mod types;

pub use client::VideoProviderClient;
pub use credentials::{load_video_provider_call, resolve_video_api_base};
pub use endpoint::{video_vendor_id_candidates, VideoApiRouting, VideoProviderCall};
pub use types::{
    VideoExportRequest, VideoExportResponse, VideoExportStatus, VideoGenerationRequest,
    VideoGenerationResponse, VideoGenerationStatus, VideoProvider,
};

#[cfg(test)]
mod http_integration;

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
        assert_eq!("doubao".parse::<VideoProvider>(), Ok(VideoProvider::Doubao));
        assert_eq!(
            "hunyuan".parse::<VideoProvider>(),
            Ok(VideoProvider::Hunyuan)
        );
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
            duration: super::types::default_duration(),
            resolution: super::types::default_resolution(),
            aspect_ratio: super::types::default_aspect_ratio(),
            image_url: None,
            seed: None,
        };
        assert_eq!(req.duration, 5);
        assert_eq!(req.resolution, "720p");
        assert_eq!(req.aspect_ratio, "16:9");
    }
}
