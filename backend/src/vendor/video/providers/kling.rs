use serde_json::json;

use crate::vendor::video::client::VideoProviderClient;
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus, VideoProvider,
};

impl VideoProviderClient {
    pub(crate) async fn generate_kling(
        &self,
        req: &VideoGenerationRequest,
        api_key: &str,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let url = format!("{}/v1/videos/generations", VideoProvider::Kling.api_base());
        let body = json!({
            "prompt": req.prompt,
            "negative_prompt": req.negative_prompt,
            "duration": req.duration,
            "aspect_ratio": req.aspect_ratio,
            "image_url": req.image_url,
            "seed": req.seed,
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
            return Err(anyhow::anyhow!("Kling API error {}: {}", status, text));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_id = result["data"]["task_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing task ID in Kling response"))?
            .to_string();

        Ok(VideoGenerationResponse {
            provider: "kling".to_string(),
            model: req.model.clone(),
            task_id,
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_kling(
        &self,
        task_id: &str,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = std::env::var("KLING_API_KEY")?;
        let url = format!(
            "{}/v1/videos/generations/{}",
            VideoProvider::Kling.api_base(),
            task_id
        );

        let resp = self
            .http
            .get(&url)
            .header("Authorization", format!("Bearer {}", api_key))
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("Kling poll error {}: {}", status, text));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_data = &result["data"];
        let status_str = task_data["status"].as_str().unwrap_or("unknown");
        let (status, video_url, error_message) = match status_str {
            "succeed" | "completed" => (
                VideoGenerationStatus::Completed,
                task_data["video_url"].as_str().map(String::from),
                None,
            ),
            "failed" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    task_data["error_msg"]
                        .as_str()
                        .unwrap_or("Unknown error")
                        .to_string(),
                ),
            ),
            "processing" | "running" => (VideoGenerationStatus::Processing, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };

        Ok(VideoGenerationResponse {
            provider: "kling".to_string(),
            model: "kling-v1".to_string(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: task_data["preview_url"].as_str().map(String::from),
            error_message,
        })
    }
}
