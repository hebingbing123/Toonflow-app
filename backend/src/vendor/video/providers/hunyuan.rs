//! Tencent Hunyuan video (VCLM) — TC3 API, not OpenAI-compatible.
//!
//! Submit: https://cloud.tencent.com/document/api/1616/126160
//! Describe: https://cloud.tencent.com/document/api/1616/126162

use serde_json::json;

use crate::vendor::http_extract::json_str;
use crate::vendor::tencent_tc3::call_vclm_action;
use crate::vendor::video::client::{VideoProviderCall, VideoProviderClient};
use crate::vendor::video::types::{
    VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus,
};

impl VideoProviderClient {
    pub(crate) async fn generate_hunyuan(
        &self,
        req: &VideoGenerationRequest,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let cfg = call.auth.tencent_tc3()?;
        let mut body = json!({ "Prompt": req.prompt });
        if let Some(url) = req.image_url.as_deref().filter(|s| !s.is_empty()) {
            body["Image"] = json!({ "Url": url });
        }
        if !req.resolution.is_empty() {
            body["Resolution"] = json!(req.resolution);
        }

        let response = call_vclm_action(&self.http, cfg, "SubmitHunyuanToVideoJob", body).await?;
        let task_id = json_str(&response, &["/JobId"])
            .ok_or_else(|| anyhow::anyhow!("Hunyuan: missing JobId"))?;

        Ok(VideoGenerationResponse {
            provider: "hunyuan".to_string(),
            model: req.model.clone(),
            task_id,
            status: VideoGenerationStatus::Queued,
            video_url: None,
            preview_url: None,
            error_message: None,
        })
    }

    pub(crate) async fn poll_hunyuan(
        &self,
        task_id: &str,
        call: &VideoProviderCall,
    ) -> anyhow::Result<VideoGenerationResponse> {
        let cfg = call.auth.tencent_tc3()?;
        let body = json!({ "JobId": task_id });
        let response = call_vclm_action(&self.http, cfg, "DescribeHunyuanToVideoJob", body).await?;
        let status_str = response["Status"].as_str().unwrap_or("WAIT");
        let (status, video_url, error_message) = match status_str {
            "DONE" => (
                VideoGenerationStatus::Completed,
                json_str(&response, &["/ResultVideoUrl"]),
                None,
            ),
            "FAIL" => (
                VideoGenerationStatus::Failed,
                None,
                Some(
                    json_str(&response, &["/ErrorMessage", "/ErrorCode"])
                        .unwrap_or_else(|| "Hunyuan generation failed".into()),
                ),
            ),
            "RUN" => (VideoGenerationStatus::Processing, None, None),
            _ => (VideoGenerationStatus::Queued, None, None),
        };

        Ok(VideoGenerationResponse {
            provider: "hunyuan".to_string(),
            model: String::new(),
            task_id: task_id.to_string(),
            status,
            video_url,
            preview_url: None,
            error_message,
        })
    }
}
