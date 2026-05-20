//! OpenAI video API (Sora-style `/v1/videos` when available on the account).

use serde_json::json;

use crate::vendor::video::client::{VideoProviderCall, VideoProviderClient};
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus, VideoProvider,
};

impl VideoProviderClient {
    pub(crate) async fn generate_openai_video(
        &self,
        req: &VideoGenerationRequest,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let url = format!("{}/v1/videos", call.api_base);
        let body = json!({
            "model": req.model,
            "prompt": req.prompt,
            "size": req.resolution,
            "seconds": req.duration,
        });

        let resp = self
            .http
            .post(&url)
            .header("Authorization", format!("Bearer {}", api_key))
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!(
                "OpenAI video API error {}: {}",
                status,
                text
            ));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_id = result["id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("OpenAI video: missing id"))?
            .to_string();

        Ok(VideoGenerationResponse {
            provider: "openai".to_string(),
            model: req.model.clone(),
            task_id,
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_openai_video(
        &self,
        task_id: &str,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let url = format!("{}/v1/videos/{task_id}", call.api_base);
        let resp = self
            .http
            .get(&url)
            .header("Authorization", format!("Bearer {}", api_key))
            .send()
            .await?;
        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!(
                "OpenAI video poll error {}: {}",
                status,
                text
            ));
        }
        let result: serde_json::Value = resp.json().await?;
        let status_str = result["status"].as_str().unwrap_or("queued");
        let (status, video_url, error_message) = match status_str {
            "completed" | "succeeded" => (
                VideoGenerationStatus::Completed,
                result
                    .pointer("/output/url")
                    .and_then(|v| v.as_str())
                    .map(String::from)
                    .or_else(|| Some(format!("{}/v1/videos/{task_id}/content", call.api_base))),
                None,
            ),
            "failed" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    result
                        .pointer("/error/message")
                        .and_then(|v| v.as_str())
                        .unwrap_or("OpenAI video failed")
                        .to_string(),
                ),
            ),
            "in_progress" | "processing" => (VideoGenerationStatus::Processing, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };
        Ok(VideoGenerationResponse {
            provider: "openai".to_string(),
            model: String::new(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: None,
            error_message,
        })
    }
}
