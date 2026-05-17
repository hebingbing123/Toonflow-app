//! Worker for **`short_video.timeline_preview`** — FFmpeg trim/concat/xfade/subtitles/VO (**M1–M3**).

use std::path::{Path, PathBuf};

use futures_util::StreamExt;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::payload_project::{
    payload_project_uuid, resolve_project_numeric_from_job_payload,
};
use crate::jobs::worker::{job_ok, JobCompletion, JobRunError};
use crate::jobs::JobRow;
use crate::short_video::assembly_query::{
    fetch_project_assembly_flat_rows, fetch_project_assembly_header,
};
use crate::short_video::timeline::{
    burn_in_style_from_project, default_tracks_from_assembly, load_timeline_row, merge_tracks,
    parse_timeline_document, TimelineTracks,
};
use crate::short_video::timeline_ffmpeg::{
    concat_demuxer_list_content, preview_pipeline_command_strings_full, FfmpegSegmentInput,
    PreviewAudioMixInput, PreviewSubtitleInput,
};
use crate::short_video::timeline_srt::write_srt_file;
use crate::state::AppState;

const MAX_SEGMENT_BYTES: u64 = 256 * 1024 * 1024;

pub(crate) async fn run_short_video_timeline_preview(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<JobCompletion, JobRunError> {
    let project_uuid = payload_project_uuid(&row.payload)
        .ok_or_else(|| JobRunError::Failed("payload missing project_uuid".into()))?;
    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, &row.payload).await?;

    let header = fetch_project_assembly_header(pool, project_uuid)
        .await
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?
        .ok_or_else(|| JobRunError::Failed("project not found for timeline preview".into()))?;

    let subtitle_style: Option<String> =
        sqlx::query_scalar(r#"SELECT subtitle_style FROM app_project WHERE id = $1"#)
            .bind(header.id)
            .fetch_optional(pool)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?
            .flatten();

    let flat = fetch_project_assembly_flat_rows(pool, header.id)
        .await
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;

    let tracks = resolve_preview_tracks(pool, project_uuid, &flat, header.bgm_strategy.as_deref())
        .await
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;

    if tracks.video.is_empty() {
        return Err(JobRunError::Failed(
            "timeline has no video clips with source_url".into(),
        ));
    }

    let root = state.local_video_export_dir.as_ref().ok_or_else(|| {
        JobRunError::Failed(
            "TOONFLOW_LOCAL_VIDEO_EXPORT_DIR is not set; cannot persist timeline preview".into(),
        )
    })?;

    let work_root = root
        .join(row.owner_user_id.to_string())
        .join(format!("{job_id}_tl"));
    tokio::fs::create_dir_all(&work_root)
        .await
        .map_err(|e| JobRunError::Failed(format!("create work dir failed: {e}")))?;

    let mut segment_inputs = Vec::new();
    for (idx, clip) in tracks.video.iter().enumerate() {
        let bytes = download_bytes_capped(&state.http_client, &clip.source_url).await?;
        let src_path = work_root.join(format!("source_{idx}.mp4"));
        tokio::fs::write(&src_path, &bytes)
            .await
            .map_err(|e| JobRunError::Failed(format!("write source segment failed: {e}")))?;
        segment_inputs.push(FfmpegSegmentInput {
            path: src_path,
            in_ms: clip.in_ms,
            out_ms: clip.out_ms,
            effect_preset_id: clip.effect_preset_id.clone(),
        });
    }

    let bgm_local = resolve_bgm_local(&state.http_client, &tracks, &work_root).await?;

    let mut vo_local = Vec::new();
    for (idx, vo) in tracks.voiceover.iter().enumerate() {
        let bytes = download_bytes_capped(&state.http_client, &vo.source_url).await?;
        let path = work_root.join(format!("vo_{idx}.bin"));
        tokio::fs::write(&path, &bytes)
            .await
            .map_err(|e| JobRunError::Failed(format!("write voiceover failed: {e}")))?;
        vo_local.push(path);
    }

    let srt_path = work_root.join("subs.srt");
    let has_srt = write_srt_file(&tracks.subtitles, &srt_path)
        .await
        .map_err(|e| JobRunError::Failed(format!("write srt: {e}")))?;

    let burn = burn_in_style_from_project(subtitle_style.as_deref());
    let subtitle_input = PreviewSubtitleInput {
        srt_path: if has_srt { Some(srt_path) } else { None },
        font_size: burn.font_size,
        margin_v: burn.margin_v,
    };

    let audio_input = PreviewAudioMixInput {
        bgm_path: bgm_local.clone(),
        bgm_volume: tracks.bgm.as_ref().map(|b| b.volume).unwrap_or(0.35),
        voiceover_clips: tracks.voiceover.clone(),
        voiceover_local_paths: vo_local,
        duck_bgm_during_voiceover: true,
    };

    let file_name = format!("{job_id}_timeline_preview.mp4");
    let output_path = root.join(row.owner_user_id.to_string()).join(&file_name);
    let preview_path = work_root.join("preview.mp4");

    run_ffmpeg_preview(
        &segment_inputs,
        &tracks.transitions,
        &work_root,
        &preview_path,
        bgm_local.as_deref(),
        tracks.bgm.as_ref().map(|b| b.volume).unwrap_or(0.35),
        &subtitle_input,
        &audio_input,
    )
    .await?;

    tokio::fs::copy(&preview_path, &output_path)
        .await
        .map_err(|e| JobRunError::Failed(format!("copy preview to export dir failed: {e}")))?;

    let _ = tokio::fs::remove_dir_all(&work_root).await;

    let preview_url = format!("/api/v1/jobs/{job_id}/file");
    let result = json!({
        "schema_version": 3,
        "preview_url": preview_url,
        "export_url": preview_url,
        "project_uuid": header.id,
        "project_numeric_id": project_numeric_id,
        "clip_count": tracks.video.len(),
        "storage": "local",
        "file_name": file_name,
        "content_type": "video/mp4",
        "last_writeback": {
            "status": "ok",
            "code": "timeline_preview_ok",
            "preview_url": preview_url,
        },
    });

    Ok(job_ok(result))
}

async fn resolve_bgm_local(
    client: &reqwest::Client,
    tracks: &TimelineTracks,
    work_root: &Path,
) -> Result<Option<PathBuf>, JobRunError> {
    if let Some(bgm) = tracks.bgm.as_ref() {
        if bgm.enabled {
            if let Some(url) = bgm
                .asset_url
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty())
            {
                let bytes = download_bytes_capped(client, url).await?;
                let path = work_root.join("bgm_audio.bin");
                tokio::fs::write(&path, &bytes)
                    .await
                    .map_err(|e| JobRunError::Failed(format!("write bgm failed: {e}")))?;
                return Ok(Some(path));
            }
        }
    }
    Ok(None)
}

async fn resolve_preview_tracks(
    pool: &PgPool,
    project_uuid: Uuid,
    flat: &[crate::short_video::assembly_query::AssemblyFlatRow],
    bgm_strategy: Option<&str>,
) -> Result<TimelineTracks, crate::error::ApiError> {
    let defaults = default_tracks_from_assembly(flat, bgm_strategy);
    let Some(row) = load_timeline_row(pool, project_uuid).await? else {
        return Ok(defaults);
    };
    let persisted = parse_timeline_document(row.schema_version, &row.timeline_json);
    Ok(merge_tracks(defaults, &persisted))
}

async fn download_bytes_capped(
    client: &reqwest::Client,
    url: &str,
) -> Result<Vec<u8>, JobRunError> {
    let url = url.trim();
    if url.is_empty() {
        return Err(JobRunError::Failed("empty download url".into()));
    }
    if url.starts_with('/') {
        return Err(JobRunError::Failed(format!(
            "relative url not supported for timeline preview download: {url}"
        )));
    }
    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| JobRunError::Failed(format!("download failed: {e}")))?;
    if !resp.status().is_success() {
        return Err(JobRunError::Failed(format!(
            "download HTTP {}",
            resp.status()
        )));
    }
    let max = MAX_SEGMENT_BYTES as usize;
    if let Some(cl) = resp.content_length() {
        if cl > max as u64 {
            return Err(JobRunError::Failed("download exceeds size cap".into()));
        }
    }
    let mut stream = resp.bytes_stream();
    let mut out = Vec::new();
    while let Some(item) = stream.next().await {
        let chunk = item.map_err(|e| JobRunError::Failed(format!("download stream: {e}")))?;
        if out.len().saturating_add(chunk.len()) > max {
            return Err(JobRunError::Failed("download body exceeds cap".into()));
        }
        out.extend_from_slice(&chunk);
    }
    Ok(out)
}

#[allow(clippy::too_many_arguments)]
async fn run_ffmpeg_preview(
    segments: &[FfmpegSegmentInput],
    transitions: &[crate::short_video::timeline::TimelineTransition],
    work_dir: &Path,
    output_mp4: &Path,
    bgm_path: Option<&Path>,
    bgm_volume: f64,
    subtitles: &PreviewSubtitleInput,
    audio: &PreviewAudioMixInput,
) -> Result<(), JobRunError> {
    let ffmpeg = which_ffmpeg()?;
    let commands = preview_pipeline_command_strings_full(
        segments,
        work_dir,
        output_mp4,
        bgm_path,
        bgm_volume,
        transitions,
        subtitles,
        audio,
    );

    let mut trimmed_paths = Vec::new();
    for (idx, _seg) in segments.iter().enumerate() {
        let out = work_dir.join(format!("seg_{idx}.mp4"));
        let args = &commands[idx];
        run_ffmpeg(&ffmpeg, args).await?;
        trimmed_paths.push(out);
    }

    let concat_idx = segments.len();
    if !crate::short_video::timeline_ffmpeg::needs_xfade_pipeline(transitions) {
        let list_file = work_dir.join("concat.txt");
        let list_body = concat_demuxer_list_content(&trimmed_paths);
        tokio::fs::write(&list_file, list_body)
            .await
            .map_err(|e| JobRunError::Failed(format!("write concat list: {e}")))?;
    }

    for cmd in commands.iter().skip(concat_idx) {
        run_ffmpeg(&ffmpeg, cmd).await?;
    }
    Ok(())
}

fn which_ffmpeg() -> Result<PathBuf, JobRunError> {
    if let Ok(path) = std::env::var("FFMPEG_PATH") {
        let trimmed = path.trim();
        if !trimmed.is_empty() {
            return Ok(PathBuf::from(trimmed));
        }
    }
    Ok(PathBuf::from("ffmpeg"))
}

async fn run_ffmpeg(ffmpeg: &Path, args: &[String]) -> Result<(), JobRunError> {
    let output = tokio::process::Command::new(ffmpeg)
        .args(args)
        .output()
        .await
        .map_err(|e| JobRunError::Failed(format!("ffmpeg spawn failed: {e}")))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(JobRunError::Failed(format!(
            "ffmpeg failed ({}): {}",
            output.status,
            stderr.chars().take(800).collect::<String>()
        )));
    }
    Ok(())
}
