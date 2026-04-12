use super::common::generation_job_is_cancelled;
use super::*;

pub(super) async fn run_video_generate(
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
    let provider = provider_str
        .parse::<VideoProvider>()
        .map_err(|_| JobRunError::Failed(format!("unknown video provider: {}", provider_str)))?;

    let model = p
        .get("model")
        .and_then(|x| x.as_str())
        .unwrap_or("default")
        .to_string();

    let prompt = p
        .get("prompt")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing prompt".into()))?;

    let negative_prompt = p
        .get("negative_prompt")
        .and_then(|x| x.as_str())
        .map(String::from);
    let duration = p
        .get("duration")
        .and_then(|x| x.as_u64())
        .map(|d| d as u32)
        .unwrap_or(5);
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
        .map(String::from);
    let seed = p.get("seed").and_then(|x| x.as_u64());

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
        .map_err(|e| JobRunError::Failed(format!("video generation submission failed: {}", e)))?;

    let max_polls = 120;
    for _poll_count in 0..max_polls {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        match gen_resp.status {
            VideoGenerationStatus::Completed => {
                break;
            }
            VideoGenerationStatus::Failed => {
                return Err(JobRunError::Failed(
                    gen_resp
                        .error_message
                        .unwrap_or_else(|| "Video generation failed".to_string()),
                ));
            }
            _ => {
                tokio::time::sleep(Duration::from_secs(1)).await;
                gen_resp = client
                    .poll_generation(provider, &gen_resp.task_id)
                    .await
                    .map_err(|e| JobRunError::Failed(format!("poll failed: {}", e)))?;
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
        if let Err(e) =
            store_video_reference(pool, row.owner_user_id, pid, sid, &video_url, &gen_resp).await
        {
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

async fn store_video_reference(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    storyboard_numeric_id: i32,
    video_url: &str,
    _resp: &crate::vendor::video::VideoGenerationResponse,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $1, state = '已完成', updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $2
          AND app_project.numeric_id = $3
          AND app_storyboard.numeric_id = $4
        "#,
    )
    .bind(video_url)
    .bind(owner_user_id)
    .bind(project_numeric_id)
    .bind(storyboard_numeric_id)
    .execute(pool)
    .await?;

    Ok(())
}

pub(super) async fn run_video_export(
    _state: &AppState,
    _pool: &PgPool,
    _job_id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let p = &row.payload;

    let source_url = p
        .get("source_url")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing source_url".into()))?;

    let format = p.get("format").and_then(|x| x.as_str()).unwrap_or("mp4");

    let target_resolution = p.get("target_resolution").and_then(|x| x.as_str());
    let include_audio = p
        .get("include_audio")
        .and_then(|x| x.as_bool())
        .unwrap_or(true);

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        source_url = %source_url,
        format = %format,
        "video export: processing"
    );

    let client = VideoProviderClient::new();
    let export_req = crate::vendor::video::VideoExportRequest {
        source_url: source_url.to_string(),
        format: format.to_string(),
        target_resolution: target_resolution.map(String::from),
        include_audio,
    };

    let export_resp = client
        .export_video(&export_req)
        .await
        .map_err(|e| JobRunError::Failed(format!("export failed: {}", e)))?;

    let export_url = export_resp
        .export_url
        .ok_or_else(|| JobRunError::Failed("no export URL in response".to_string()))?;

    Ok(json!({
        "source": "video.export",
        "task_id": export_resp.task_id,
        "status": export_resp.status.as_str(),
        "export_url": export_url,
        "format": format,
        "include_audio": include_audio,
    }))
}
