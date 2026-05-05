use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::common::{generation_job_is_cancelled, job_ok, job_ok_with_details};
use crate::jobs::worker::{JobCompletion, JobRunError};
use crate::jobs::{JobRow, JOB_KIND_VIDEO_GENERATE};
use crate::state::AppState;
use crate::vendor::video::{
    VideoGenerationRequest, VideoGenerationStatus, VideoProvider, VideoProviderClient,
};

use super::storage::{
    payload_coerced_i32, store_video_reference, video_file_writeback_error_details,
};

pub(crate) async fn run_video_generate(
    _state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<JobCompletion, JobRunError> {
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

    let project_numeric_id = payload_coerced_i32(p, "project_numeric_id");
    let script_numeric_id = payload_coerced_i32(p, "script_id");
    let storyboard_id = payload_coerced_i32(p, "storyboard_numeric_id");

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

    let (writeback, error_details) = match (project_numeric_id, storyboard_id) {
        (None, _) | (_, None) => {
            let msg = "missing project_numeric_id or storyboard_numeric_id; video URL was not written to app_storyboard.file_path";
            (
                json!({
                    "status": "skipped_missing_scope",
                    "code": "video_generate_writeback_skipped_missing_scope",
                    "detail": msg,
                }),
                Some(video_file_writeback_error_details(
                    JOB_KIND_VIDEO_GENERATE,
                    "video_generate_writeback_skipped_missing_scope",
                    msg,
                    project_numeric_id,
                    script_numeric_id,
                    storyboard_id,
                )),
            )
        }
        (Some(pid), Some(sid)) => {
            match store_video_reference(pool, row.owner_user_id, pid, sid, &video_url).await {
                Ok(0) => {
                    let msg = "UPDATE matched no storyboard row (check project/storyboard numeric ids and ownership)";
                    tracing::warn!(job_id = %row.id, message = %msg, "video writeback matched no rows");
                    (
                        json!({
                            "status": "no_row_matched",
                            "code": "video_generate_writeback_no_row_matched",
                            "detail": msg,
                        }),
                        Some(video_file_writeback_error_details(
                            JOB_KIND_VIDEO_GENERATE,
                            "video_generate_writeback_no_row_matched",
                            msg,
                            Some(pid),
                            script_numeric_id,
                            Some(sid),
                        )),
                    )
                }
                Ok(_) => (
                    json!({
                        "status": "ok",
                        "code": "video_generate_writeback_ok",
                    }),
                    None,
                ),
                Err(e) => {
                    let msg = format!("database error persisting video URL: {e}");
                    tracing::warn!(job_id = %row.id, error = %e, "video writeback failed");
                    (
                        json!({
                            "status": "sql_error",
                            "code": "video_generate_writeback_sql_error",
                            "detail": msg,
                        }),
                        Some(video_file_writeback_error_details(
                            JOB_KIND_VIDEO_GENERATE,
                            "video_generate_writeback_sql_error",
                            &msg,
                            Some(pid),
                            script_numeric_id,
                            Some(sid),
                        )),
                    )
                }
            }
        }
    };

    let mut result = json!({
        "source": "video.generate",
        "provider": provider_str,
        "model": gen_resp.model,
        "task_id": gen_resp.task_id,
        "video_url": video_url,
        "preview_url": gen_resp.preview_url,
        "project_numeric_id": project_numeric_id,
        "script_numeric_id": script_numeric_id,
        "storyboard_numeric_id": storyboard_id,
    });
    if let Some(obj) = result.as_object_mut() {
        obj.insert("writeback".to_string(), writeback);
    }

    Ok(match error_details {
        Some(d) => job_ok_with_details(result, d),
        None => job_ok(result),
    })
}
