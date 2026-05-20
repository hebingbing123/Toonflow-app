//! MiniMax / Hailuo video generation.

use serde_json::json;

use crate::vendor::video::client::{VideoProviderCall, VideoProviderClient};
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus,
};

impl VideoProviderClient {
    pub(crate) async fn generate_minimax(
        &self,
        req: &VideoGenerationRequest,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let url = format!("{}/v1/video_generation", call.api_base);
        let body = json!({
            "model": req.model,
            "prompt": req.prompt,
            "duration": req.duration,
            "resolution": req.resolution,
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
                "MiniMax video API error {}: {}",
                status,
                text
            ));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_id = result["task_id"]
            .as_str()
            .or_else(|| result["data"]["task_id"].as_str())
            .ok_or_else(|| anyhow::anyhow!("MiniMax: missing task id"))?
            .to_string();

        Ok(VideoGenerationResponse {
            provider: "minimax".to_string(),
            model: req.model.clone(),
            task_id,
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_minimax(
        &self,
        task_id: &str,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let url = format!("{}/v1/query/video_generation", call.api_base);
        let resp = self
            .http
            .get(&url)
            .query(&[("task_id", task_id)])
            .header("Authorization", format!("Bearer {}", api_key))
            .send()
            .await?;
        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("MiniMax poll error {}: {}", status, text));
        }
        let result: serde_json::Value = resp.json().await?;
        let status_str = result["status"].as_str().unwrap_or("Queueing");
        let (status, video_url, error_message) = match status_str {
            "Success" | "success" => {
                let file_id = result.get("file_id").and_then(|v| v.as_str());
                let download_url = if let Some(fid) = file_id {
                    self.fetch_minimax_file_download_url(fid, api_key, &call.api_base)
                        .await
                        .ok()
                } else {
                    None
                };
                (VideoGenerationStatus::Completed, download_url, None)
            }
            "Fail" | "failed" => (
                VideoGenerationStatus::Failed,
                None,
                Some("MiniMax generation failed".to_string()),
            ),
            "Processing" | "Running" => (VideoGenerationStatus::Processing, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };
        Ok(VideoGenerationResponse {
            provider: "minimax".to_string(),
            model: String::new(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: None,
            error_message,
        })
    }

    async fn fetch_minimax_file_download_url(
        &self,
        file_id: &str,
        api_key: &str,
        api_base: &str,
    ) -> anyhow::Result<String> {
        let url = format!("{api_base}/v1/files/retrieve");
        let resp = self
            .http
            .get(&url)
            .query(&[("file_id", file_id)])
            .header("Authorization", format!("Bearer {}", api_key))
            .send()
            .await?;
        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!(
                "MiniMax file retrieve {}: {}",
                status,
                text
            ));
        }
        let result: serde_json::Value = resp.json().await?;
        result
            .pointer("/file/download_url")
            .and_then(|v| v.as_str())
            .map(String::from)
            .ok_or_else(|| anyhow::anyhow!("MiniMax: missing file.download_url"))
    }
}
