use serde_json::json;

use crate::vendor::video::client::VideoProviderClient;
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus, VideoProvider,
};

impl VideoProviderClient {
    pub(crate) async fn generate_runway(
        &self,
        req: &VideoGenerationRequest,
        api_key: &str,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let url = format!("{}/v1/generation", VideoProvider::Runway.api_base());
        let body = if let Some(image_url) = &req.image_url {
            json!({
                "prompt": req.prompt,
                "negative_prompt": req.negative_prompt,
                "duration": req.duration,
                "ratio": req.aspect_ratio,
                "image_url": image_url,
                "seed": req.seed,
            })
        } else {
            json!({
                "prompt": req.prompt,
                "negative_prompt": req.negative_prompt,
                "duration": req.duration,
                "ratio": req.aspect_ratio,
                "seed": req.seed,
            })
        };

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
            return Err(anyhow::anyhow!("Runway API error {}: {}", status, text));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_id = result["id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing task ID in Runway response"))?
            .to_string();

        Ok(VideoGenerationResponse {
            provider: "runway".to_string(),
            model: req.model.clone(),
            task_id,
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_runway(
        &self,
        task_id: &str,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = std::env::var("RUNWAY_API_KEY")?;
        let url = format!(
            "{}/v1/generation/{}",
            VideoProvider::Runway.api_base(),
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
            return Err(anyhow::anyhow!("Runway poll error {}: {}", status, text));
        }

        let result: serde_json::Value = resp.json().await?;
        let status_str = result["status"].as_str().unwrap_or("unknown");
        let (status, video_url, error_message) = match status_str {
            "SUCCEEDED" | "completed" => (
                VideoGenerationStatus::Completed,
                result["url"].as_str().map(String::from),
                None,
            ),
            "FAILED" | "failed" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    result["error"]["message"]
                        .as_str()
                        .unwrap_or("Unknown error")
                        .to_string(),
                ),
            ),
            "RUNNING" | "processing" => (VideoGenerationStatus::Processing, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };

        Ok(VideoGenerationResponse {
            provider: "runway".to_string(),
            model: "gen-2".to_string(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: result["preview_url"].as_str().map(String::from),
            error_message,
        })
    }
}
