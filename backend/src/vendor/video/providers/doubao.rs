//! Volcengine Ark / Doubao Seedance video (content generation tasks API).

use serde_json::json;

use crate::vendor::video::client::{VideoProviderCall, VideoProviderClient};
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus,
};

impl VideoProviderClient {
    pub(crate) async fn generate_doubao(
        &self,
        req: &VideoGenerationRequest,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let url = format!("{}/api/v3/contents/generations/tasks", call.api_base);
        let mut body = json!({
            "model": req.model,
            "content": [{
                "type": "text",
                "text": req.prompt,
            }],
            "duration": req.duration,
            "ratio": req.aspect_ratio,
            "resolution": req.resolution,
            "watermark": false,
        });
        if let Some(url) = req.image_url.as_deref() {
            if let Some(arr) = body.get_mut("content").and_then(|c| c.as_array_mut()) {
                arr.push(json!({
                    "type": "image_url",
                    "image_url": { "url": url },
                }));
            }
        }

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
                "Doubao video API error {}: {}",
                status,
                text
            ));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_id = result["id"]
            .as_str()
            .or_else(|| result["data"]["id"].as_str())
            .ok_or_else(|| anyhow::anyhow!("Doubao: missing task id"))?
            .to_string();

        Ok(VideoGenerationResponse {
            provider: "doubao".to_string(),
            model: req.model.clone(),
            task_id,
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_doubao(
        &self,
        task_id: &str,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let url = format!(
            "{}/api/v3/contents/generations/tasks/{}",
            call.api_base, task_id
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
            return Err(anyhow::anyhow!("Doubao poll error {}: {}", status, text));
        }
        let result: serde_json::Value = resp.json().await?;
        let status_str = result["status"]
            .as_str()
            .or_else(|| result["data"]["status"].as_str())
            .unwrap_or("queued");
        let (status, video_url, error_message) = match status_str {
            "succeeded" | "completed" | "success" => (
                VideoGenerationStatus::Completed,
                result
                    .pointer("/content/video_url")
                    .or_else(|| result.pointer("/data/output/video_url"))
                    .and_then(|v| v.as_str())
                    .map(String::from),
                None,
            ),
            "failed" | "error" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    result
                        .pointer("/error/message")
                        .and_then(|v| v.as_str())
                        .unwrap_or("Doubao generation failed")
                        .to_string(),
                ),
            ),
            "running" | "processing" => (VideoGenerationStatus::Processing, None, None),
            "expired" | "cancelled" => (
                VideoGenerationStatus::Failed,
                None,
                Some(format!("Doubao task {status_str}")),
            ),
            "queued" => (VideoGenerationStatus::Queued, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };
        Ok(VideoGenerationResponse {
            provider: "doubao".to_string(),
            model: String::new(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: None,
            error_message,
        })
    }
}
