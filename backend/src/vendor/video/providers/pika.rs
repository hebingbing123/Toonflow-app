//! Pika via fal.ai queue API — https://docs.fal.ai/model-apis/model-endpoints/queue/
//!
//! Public Pika models are hosted on `queue.fal.run`, not `api.pika.art`.

use serde_json::json;

use crate::vendor::http_extract::{json_str, json_url};
use crate::vendor::video::client::{VideoProviderCall, VideoProviderClient};
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus,
};

fn fal_pika_endpoint(req: &VideoGenerationRequest) -> &'static str {
    let has_image = req
        .image_url
        .as_deref()
        .map(str::trim)
        .is_some_and(|s| !s.is_empty());
    if has_image {
        "fal-ai/pika/v2.2/image-to-video"
    } else {
        "fal-ai/pika/v2.2/text-to-video"
    }
}

fn parse_fal_task_id(task_id: &str) -> (&str, &str) {
    if let Some((_prefix, rest)) = task_id.split_once('|') {
        if let Some((endpoint, request_id)) = rest.split_once('|') {
            return (endpoint, request_id);
        }
    }
    ("fal-ai/pika/v2.2/text-to-video", task_id)
}

fn encode_fal_task_id(endpoint: &str, request_id: &str) -> String {
    format!("fal|{endpoint}|{request_id}")
}

impl VideoProviderClient {
    pub(crate) async fn generate_pika(
        &self,
        req: &VideoGenerationRequest,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let endpoint = fal_pika_endpoint(req);
        let url = format!("{}/{endpoint}", call.api_base);
        let mut body = json!({
            "prompt": req.prompt,
            "aspect_ratio": req.aspect_ratio,
        });
        if let Some(image) = req.image_url.as_deref().filter(|s| !s.is_empty()) {
            body["image_url"] = json!(image);
        }
        if req.duration > 0 {
            body["duration"] = json!(req.duration);
        }

        let resp = self
            .http
            .post(&url)
            .header("Authorization", format!("Key {api_key}"))
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("fal/Pika API error {status}: {text}"));
        }

        let result: serde_json::Value = resp.json().await?;
        let request_id = json_str(&result, &["/request_id"])
            .ok_or_else(|| anyhow::anyhow!("fal/Pika: missing request_id"))?;

        Ok(VideoGenerationResponse {
            provider: "pika".to_string(),
            model: req.model.clone(),
            task_id: encode_fal_task_id(endpoint, &request_id),
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_pika(
        &self,
        task_id: &str,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let api_key = call.auth.bearer_token()?;
        let (endpoint, request_id) = parse_fal_task_id(task_id);
        let status_url = format!("{}/{endpoint}/requests/{request_id}/status", call.api_base);

        let resp = self
            .http
            .get(&status_url)
            .header("Authorization", format!("Key {api_key}"))
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("fal/Pika poll error {status}: {text}"));
        }

        let result: serde_json::Value = resp.json().await?;
        let status_str = result["status"].as_str().unwrap_or("IN_QUEUE");
        let (status, video_url, error_message) = match status_str {
            "COMPLETED" => {
                let result_url = format!("{}/{endpoint}/requests/{request_id}", call.api_base);
                let video_url = self.fetch_fal_video_url(&result_url, api_key).await.ok();
                (VideoGenerationStatus::Completed, video_url, None)
            }
            "FAILED" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    json_str(&result, &["/error", "/detail"])
                        .unwrap_or_else(|| "fal/Pika generation failed".into()),
                ),
            ),
            "IN_PROGRESS" => (VideoGenerationStatus::Processing, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };

        Ok(VideoGenerationResponse {
            provider: "pika".to_string(),
            model: String::new(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: None,
            error_message,
        })
    }

    async fn fetch_fal_video_url(&self, result_url: &str, api_key: &str) -> anyhow::Result<String> {
        let resp = self
            .http
            .get(result_url)
            .header("Authorization", format!("Key {api_key}"))
            .send()
            .await?;
        let result: serde_json::Value = resp.json().await?;
        json_url(
            &result,
            &[
                "/video/url",
                "/video/0/url",
                "/data/video/url",
                "/output/video/url",
            ],
        )
        .ok_or_else(|| anyhow::anyhow!("fal result missing video url"))
    }
}
