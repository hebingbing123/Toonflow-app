//! Kling official video API — https://api.klingai.com
//!
//! `POST /v1/videos/text2video` | `image2video`, poll `GET /v1/videos/{kind}/{task_id}`.

use serde_json::json;

use crate::vendor::http_extract::{json_str, json_url};
use crate::vendor::video::client::{VideoProviderCall, VideoProviderClient};
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus,
};

fn kling_duration(req: &VideoGenerationRequest) -> String {
    if req.duration >= 10 {
        "10".to_string()
    } else {
        "5".to_string()
    }
}

fn kling_video_kind(req: &VideoGenerationRequest) -> &'static str {
    if req
        .image_url
        .as_deref()
        .map(str::trim)
        .is_some_and(|s| !s.is_empty())
    {
        "image2video"
    } else {
        "text2video"
    }
}

impl VideoProviderClient {
    pub(crate) async fn generate_kling(
        &self,
        req: &VideoGenerationRequest,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let bearer = call.auth.bearer_token()?;
        let kind = kling_video_kind(req);
        let url = format!("{}/v1/videos/{}", call.api_base, kind);
        let mut body = json!({
            "model_name": req.model,
            "mode": "std",
            "prompt": req.prompt,
            "duration": kling_duration(req),
            "aspect_ratio": req.aspect_ratio,
        });
        if let Some(neg) = req.negative_prompt.as_deref().filter(|s| !s.is_empty()) {
            body["negative_prompt"] = json!(neg);
        }
        if let Some(image) = req.image_url.as_deref().filter(|s| !s.is_empty()) {
            body["image"] = json!(image);
        }

        let resp = self
            .http
            .post(&url)
            .header("Authorization", format!("Bearer {bearer}"))
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("Kling API error {status}: {text}"));
        }

        let result: serde_json::Value = resp.json().await?;
        let task_id = json_str(&result, &["/data/task_id", "/task_id"])
            .ok_or_else(|| anyhow::anyhow!("Kling: missing task_id"))?;

        Ok(VideoGenerationResponse {
            provider: "kling".to_string(),
            model: req.model.clone(),
            task_id: format!("{kind}:{task_id}"),
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_kling(
        &self,
        task_id: &str,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let bearer = call.auth.bearer_token()?;
        let (kind, id) = task_id.split_once(':').unwrap_or(("text2video", task_id));
        let url = format!("{}/v1/videos/{}/{}", call.api_base, kind, id);

        let resp = self
            .http
            .get(&url)
            .header("Authorization", format!("Bearer {bearer}"))
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("Kling poll error {status}: {text}"));
        }

        let result: serde_json::Value = resp.json().await?;
        let data = &result["data"];
        let status_str = data["task_status"]
            .as_str()
            .or_else(|| data["status"].as_str())
            .unwrap_or("unknown");
        let (status, video_url, error_message) = match status_str {
            "succeed" | "succeeded" | "completed" => (
                VideoGenerationStatus::Completed,
                json_url(
                    data,
                    &[
                        "/task_result/videos/0/url",
                        "/task_result/video_url",
                        "/video_url",
                    ],
                ),
                None,
            ),
            "failed" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    json_str(data, &["/task_status_msg", "/error_msg", "/message"])
                        .unwrap_or_else(|| "Kling generation failed".into()),
                ),
            ),
            "processing" | "running" | "submitted" => {
                (VideoGenerationStatus::Processing, None, None)
            }
            _ => (VideoGenerationStatus::Queued, None, None),
        };

        Ok(VideoGenerationResponse {
            provider: "kling".to_string(),
            model: String::new(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: json_str(data, &["/task_result/videos/0/cover_url"]),
            error_message,
        })
    }
}
