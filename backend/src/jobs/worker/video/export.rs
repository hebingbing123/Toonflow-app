use futures_util::StreamExt;
use serde_json::{json, Map};
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::JobRunError;
use crate::jobs::{JobRow, JOB_KIND_VIDEO_EXPORT};
use crate::state::AppState;
use crate::vendor::video::{VideoExportRequest, VideoProviderClient};

use super::storage::store_video_reference;

fn structured_video_export_failure(
    row: &JobRow,
    code: &'static str,
    message: impl Into<String>,
) -> JobRunError {
    let message = message.into();
    let p = &row.payload;
    let mut links = Map::new();
    for key in [
        "project_numeric_id",
        "script_numeric_id",
        "storyboard_numeric_id",
    ] {
        if let Some(n) = p.get(key).and_then(|x| x.as_i64()) {
            links.insert(key.to_string(), json!(n));
        }
    }
    JobRunError::FailedStructured {
        message: message.clone(),
        error_details: json!({
            "schema_version": 1,
            "code": code,
            "job_kind": JOB_KIND_VIDEO_EXPORT,
            "message": message,
            "deep_links": links,
        }),
    }
}

pub(crate) async fn run_video_export(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let p = &row.payload;

    let source_url = p
        .get("source_url")
        .and_then(|x| x.as_str())
        .ok_or_else(|| {
            structured_video_export_failure(
                row,
                "payload_missing_source_url",
                "payload missing source_url",
            )
        })?;
    let source_url = source_url.trim();
    if source_url.is_empty() {
        return Err(structured_video_export_failure(
            row,
            "payload_source_url_empty",
            "payload source_url cannot be empty",
        ));
    }

    let format = p.get("format").and_then(|x| x.as_str()).unwrap_or("mp4");
    let format_norm = format.trim().to_ascii_lowercase();
    if !matches!(format_norm.as_str(), "mp4" | "mov" | "webm") {
        return Err(structured_video_export_failure(
            row,
            "payload_format_invalid",
            format!("payload format must be mp4/mov/webm (got {format})"),
        ));
    }
    let target_resolution = p.get("target_resolution").and_then(|x| x.as_str());
    let include_audio = p
        .get("include_audio")
        .and_then(|x| x.as_bool())
        .unwrap_or(true);

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
        source_url = %source_url,
        format = %format,
        "video export: processing"
    );

    let root = state.local_video_export_dir.as_ref().ok_or_else(|| {
        structured_video_export_failure(
            row,
            "local_export_dir_unset",
            "TOONFLOW_LOCAL_VIDEO_EXPORT_DIR is not set; cannot persist exported video artifact",
        )
    })?;

    let client = VideoProviderClient::new();
    let export_req = VideoExportRequest {
        source_url: source_url.to_string(),
        format: format_norm.clone(),
        target_resolution: target_resolution.map(String::from),
        include_audio,
    };

    let export_resp = client.export_video(&export_req).await.map_err(|e| {
        structured_video_export_failure(
            row,
            "export_provider_failed",
            format!("export failed: {e}"),
        )
    })?;

    let (bytes, content_type) =
        download_video_bytes_capped(row, &state.http_client, source_url, &format_norm).await?;
    let user_dir = root.join(row.owner_user_id.to_string());
    tokio::fs::create_dir_all(&user_dir).await.map_err(|e| {
        structured_video_export_failure(
            row,
            "export_directory_create_failed",
            format!("failed to create export directory: {e}"),
        )
    })?;
    let file_name = format!("{job_id}.{format_norm}");
    let disk_path = user_dir.join(&file_name);
    tokio::fs::write(&disk_path, &bytes).await.map_err(|e| {
        structured_video_export_failure(
            row,
            "export_file_persist_failed",
            format!("failed to persist exported video: {e}"),
        )
    })?;
    let export_url = format!("/api/v1/jobs/{job_id}/file");

    if let (Some(pid), Some(sid)) = (project_numeric_id, storyboard_id) {
        if let Err(e) = store_video_reference(pool, row.owner_user_id, pid, sid, &export_url).await
        {
            tracing::warn!(error = %e, "failed to store video export reference");
        }
    }

    Ok(json!({
        "source": "video.export",
        "task_id": export_resp.task_id,
        "status": export_resp.status.as_str(),
        "export_url": export_url,
        "format": format_norm,
        "include_audio": include_audio,
        "storage": "local",
        "file_name": file_name,
        "content_type": content_type,
        "byte_length": bytes.len(),
        "source_url": source_url,
        "project_numeric_id": project_numeric_id,
        "storyboard_numeric_id": storyboard_id,
    }))
}

const MAX_DOWNLOADED_VIDEO_EXPORT_BYTES: u64 = 512 * 1024 * 1024;

async fn download_video_bytes_capped(
    row: &JobRow,
    client: &reqwest::Client,
    url: &str,
    expected_format: &str,
) -> Result<(Vec<u8>, Option<String>), JobRunError> {
    let resp = client.get(url).send().await.map_err(|e| {
        structured_video_export_failure(row, "video_download_stream", e.to_string())
    })?;
    if !resp.status().is_success() {
        return Err(structured_video_export_failure(
            row,
            "video_download_http",
            format!("video download HTTP {}", resp.status()),
        ));
    }
    let content_type = resp
        .headers()
        .get(reqwest::header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);
    if let Some(actual_format) = infer_video_format(url, content_type.as_deref()) {
        if actual_format != expected_format {
            return Err(structured_video_export_failure(
                row,
                "video_format_mismatch_no_transcode",
                format!(
                    "requested format {expected_format} does not match downloadable source format {actual_format}; transcoding is not implemented yet"
                ),
            ));
        }
    }
    let max = MAX_DOWNLOADED_VIDEO_EXPORT_BYTES as usize;
    if let Some(cl) = resp.content_length() {
        if cl > max as u64 {
            return Err(structured_video_export_failure(
                row,
                "video_content_length_exceeds_limit",
                "video Content-Length exceeds export limit",
            ));
        }
    }
    let mut stream = resp.bytes_stream();
    let mut out = Vec::new();
    while let Some(item) = stream.next().await {
        let chunk = item.map_err(|e| {
            structured_video_export_failure(row, "video_download_stream", e.to_string())
        })?;
        if out.len().saturating_add(chunk.len()) > max {
            return Err(structured_video_export_failure(
                row,
                "video_body_exceeds_limit",
                "video body exceeds export limit",
            ));
        }
        out.extend_from_slice(&chunk);
    }
    Ok((out, content_type))
}

fn infer_video_format(url: &str, content_type: Option<&str>) -> Option<&'static str> {
    let from_url = reqwest::Url::parse(url)
        .ok()
        .and_then(|parsed| {
            parsed
                .path_segments()
                .and_then(|mut segments| segments.next_back())
                .and_then(|name| name.rsplit('.').next())
                .map(|ext| ext.trim().to_ascii_lowercase())
        })
        .and_then(|ext| match ext.as_str() {
            "mp4" => Some("mp4"),
            "mov" => Some("mov"),
            "webm" => Some("webm"),
            _ => None,
        });
    if from_url.is_some() {
        return from_url;
    }
    content_type.and_then(|value| {
        let normalized = value
            .split(';')
            .next()
            .unwrap_or(value)
            .trim()
            .to_ascii_lowercase();
        match normalized.as_str() {
            "video/mp4" => Some("mp4"),
            "video/quicktime" => Some("mov"),
            "video/webm" => Some("webm"),
            _ => None,
        }
    })
}

#[cfg(test)]
mod tests {
    use super::infer_video_format;

    #[test]
    fn infer_video_format_prefers_url_extension() {
        assert_eq!(
            infer_video_format(
                "https://cdn.example.com/story/final.mov?x=1",
                Some("video/mp4")
            ),
            Some("mov")
        );
    }

    #[test]
    fn infer_video_format_falls_back_to_content_type() {
        assert_eq!(
            infer_video_format("https://cdn.example.com/download", Some("video/webm")),
            Some("webm")
        );
    }

    #[test]
    fn infer_video_format_returns_none_for_unknown_source() {
        assert_eq!(
            infer_video_format(
                "https://cdn.example.com/download",
                Some("application/octet-stream")
            ),
            None
        );
    }
}
