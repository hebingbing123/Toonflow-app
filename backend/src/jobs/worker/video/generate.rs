use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::common::generation_job_is_cancelled;
use crate::jobs::worker::JobRunError;
use crate::jobs::JobRow;
use crate::state::AppState;
use crate::vendor::video::{
    VideoGenerationRequest, VideoGenerationStatus, VideoProvider, VideoProviderClient,
};

use super::storage::store_video_reference;

pub(crate) async fn run_video_generate(
    _state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let p = &row.payload;

    let provider_str = p
        .get("provider")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing provider".into()))?;
    let provider_str = provider_str.trim();
    if provider_str.is_empty() {
        return Err(JobRunError::Failed(
            "payload provider cannot be empty".into(),
        ));
    }
    let provider = provider_str
        .parse::<VideoProvider>()
        .map_err(|_| JobRunError::Failed(format!("unknown video provider: {provider_str}")))?;

    let model = p
        .get("model")
        .and_then(|x| x.as_str())
        .unwrap_or("default")
        .to_string();

    let prompt = p
        .get("prompt")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing prompt".into()))?;
    let prompt = prompt.trim();
    if prompt.is_empty() {
        return Err(JobRunError::Failed("payload prompt cannot be empty".into()));
    }

    let negative_prompt = p
        .get("negative_prompt")
        .and_then(|x| x.as_str())
        .map(String::from);
    let duration = p
        .get("duration")
        .and_then(|x| x.as_u64())
        .map(|d| d as u32)
        .unwrap_or(5);
    if !(1..=60).contains(&duration) {
        return Err(JobRunError::Failed(format!(
            "payload duration must be between 1 and 60 seconds (got {duration})"
        )));
    }
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .map(String::from)
        .unwrap_or_else(|| "720p".to_string());
    let aspect_ratio = p
        .get("aspect_ratio")
        .and_then(|x| x.as_str())
        .map(String::from)
        .unwrap_or_else(|| "16:9".to_string());
    let image_url = p
        .get("image_url")
        .and_then(|x| x.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(String::from);
    let seed = p.get("seed").and_then(|x| x.as_u64());

    if let Some(url) = image_url.as_deref() {
        let parsed = reqwest::Url::parse(url)
            .map_err(|e| JobRunError::Failed(format!("invalid payload image_url: {e}")))?;
        match parsed.scheme() {
            "http" | "https" => {}
            other => {
                return Err(JobRunError::Failed(format!(
                    "unsupported payload image_url scheme: {other} (expected http/https)"
                )));
            }
        }
    }

    let project_numeric_id = p
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok());
    let storyboard_id = p
        .get("storyboard_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok());

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        provider = %provider.name(),
        model = %model,
        "video generation: submitting to provider"
    );

    let client = VideoProviderClient::new();
    let req = VideoGenerationRequest {
        provider,
        model,
        prompt: prompt.to_string(),
        negative_prompt,
        duration,
        resolution,
        aspect_ratio,
        image_url,
        seed,
    };

    let mut gen_resp = client
        .generate_video(&req)
        .await
        .map_err(|e| JobRunError::Failed(format!("video generation submission failed: {e}")))?;

    let max_polls = 120;
    for _ in 0..max_polls {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        match gen_resp.status {
            VideoGenerationStatus::Completed => break,
            VideoGenerationStatus::Failed => {
                return Err(JobRunError::Failed(
                    gen_resp
                        .error_message
                        .unwrap_or_else(|| "Video generation failed".to_string()),
                ));
            }
            _ => {
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                gen_resp = client
                    .poll_generation(provider, &gen_resp.task_id)
                    .await
                    .map_err(|e| JobRunError::Failed(format!("poll failed: {e}")))?;
            }
        }
    }

    if gen_resp.status != VideoGenerationStatus::Completed {
        return Err(JobRunError::Failed("video generation timeout".to_string()));
    }

    let video_url = gen_resp
        .video_url
        .clone()
        .ok_or_else(|| JobRunError::Failed("no video URL in completed response".to_string()))?;

    if let (Some(pid), Some(sid)) = (project_numeric_id, storyboard_id) {
        if let Err(e) = store_video_reference(pool, row.owner_user_id, pid, sid, &video_url).await {
            tracing::warn!(error = %e, "failed to store video reference");
        }
    }

    Ok(json!({
        "source": "video.generate",
        "provider": provider_str,
        "model": gen_resp.model,
        "task_id": gen_resp.task_id,
        "video_url": video_url,
        "preview_url": gen_resp.preview_url,
        "project_numeric_id": project_numeric_id,
        "storyboard_numeric_id": storyboard_id,
    }))
}
