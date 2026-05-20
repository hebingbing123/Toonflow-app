//! Runway API — https://docs.dev.runwayml.com/api/
//!
//! `POST /v1/text_to_video` | `/v1/image_to_video`, poll `GET /v1/tasks/{id}`.

use serde_json::json;

use crate::vendor::http_extract::{json_str, json_url};
use crate::vendor::video::client::{VideoProviderCall, VideoProviderClient};
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus,
};

const RUNWAY_VERSION: &str = "2024-11-06";

impl VideoProviderClient {
    pub(crate) async fn generate_runway(
        &self,
        req: &VideoGenerationRequest,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let bearer = call.auth.bearer_token()?;
        let base = &call.api_base;
        let path = if req
            .image_url
            .as_deref()
            .map(str::trim)
            .is_some_and(|s| !s.is_empty())
        {
            "/v1/image_to_video"
        } else {
            "/v1/text_to_video"
        };
        let url = format!("{base}{path}");
        let mut body = json!({
            "model": req.model,
            "prompt": req.prompt,
            "duration": req.duration,
            "ratio": req.aspect_ratio,
        });
        if let Some(image) = req.image_url.as_deref().filter(|s| !s.is_empty()) {
            body["image"] = json!(image);
        }
        if let Some(seed) = req.seed {
            body["seed"] = json!(seed);
        }

        let resp = self
            .http
            .post(&url)
            .header("Authorization", format!("Bearer {bearer}"))
            .header("X-Runway-Version", RUNWAY_VERSION)
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("Runway API error {status}: {text}"));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_id = json_str(&result, &["/id"])
            .ok_or_else(|| anyhow::anyhow!("Runway: missing task id"))?;

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
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let bearer = call.auth.bearer_token()?;
        let url = format!("{}/v1/tasks/{}", call.api_base, task_id);

        let resp = self
            .http
            .get(&url)
            .header("Authorization", format!("Bearer {bearer}"))
            .header("X-Runway-Version", RUNWAY_VERSION)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("Runway poll error {status}: {text}"));
        }

        let result: serde_json::Value = resp.json().await?;
        let status_str = result["status"].as_str().unwrap_or("unknown");
        let (status, video_url, error_message) = match status_str.to_ascii_uppercase().as_str() {
            "SUCCEEDED" | "COMPLETED" => (
                VideoGenerationStatus::Completed,
                json_url(
                    &result,
                    &["/output/0", "/output/0/url", "/artifacts/0/url", "/url"],
                ),
                None,
            ),
            "FAILED" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    json_str(&result, &["/failure", "/failure/message", "/error/message"])
                        .unwrap_or_else(|| "Runway generation failed".into()),
                ),
            ),
            "RUNNING" | "PROCESSING" => (VideoGenerationStatus::Processing, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };

        Ok(VideoGenerationResponse {
            provider: "runway".to_string(),
            model: String::new(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: json_str(&result, &["/preview_url"]),
            error_message,
        })
    }
}
