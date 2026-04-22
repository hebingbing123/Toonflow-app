//! 分镜导出：拉取字节并写入 zip。

use std::io::{Cursor, Write};

use axum::http::header;
use serde::Serialize;
use zip::write::FileOptions;

use super::super::export_source::{
    infer_export_extension, parse_storyboard_export_source, StoryboardExportSource,
};
use super::super::types::ExportImageSourceRow;
use crate::error::ApiError;
use crate::state::AppState;

pub(super) async fn build_storyboard_export_zip(
    state: &AppState,
    owner_user_id: uuid::Uuid,
    rows: Vec<ExportImageSourceRow>,
) -> Result<Vec<u8>, ApiError> {
    let mut archive = zip::ZipWriter::new(Cursor::new(Vec::new()));
    let options = FileOptions::default().compression_method(zip::CompressionMethod::Deflated);
    let mut manifest_rows = Vec::with_capacity(rows.len());

    for (order_index, row) in rows.into_iter().enumerate() {
        manifest_rows.push(StoryboardExportManifestShot::from_row(&row, order_index));
        let file_path = row.file_path.as_deref().ok_or_else(|| {
            ApiError::BadRequest(format!(
                "storyboard {} has no generated image to export",
                row.numeric_id
            ))
        })?;

        let exported =
            fetch_storyboard_export_bytes(state, owner_user_id, row.numeric_id, file_path).await?;
        archive
            .start_file(exported.filename, options)
            .map_err(|_| ApiError::Internal)?;
        archive
            .write_all(&exported.bytes)
            .map_err(|_| ApiError::Internal)?;
    }

    let storyboard_csv = build_storyboard_csv(&manifest_rows);
    let timeline = build_storyboard_timeline(&manifest_rows);
    let subtitles = build_storyboard_srt(&manifest_rows);
    write_export_text_file(
        &mut archive,
        "manifest.json",
        &serde_json::to_vec_pretty(&StoryboardExportManifest {
            export_type: "storyboard_image_bundle",
            shot_count: manifest_rows.len(),
            shots: manifest_rows,
        })
        .map_err(|_| ApiError::Internal)?,
        options,
    )?;
    write_export_text_file(
        &mut archive,
        "storyboard.csv",
        storyboard_csv.as_bytes(),
        options,
    )?;
    write_export_text_file(
        &mut archive,
        "timeline.json",
        &serde_json::to_vec_pretty(&timeline).map_err(|_| ApiError::Internal)?,
        options,
    )?;
    write_export_text_file(&mut archive, "subtitles.srt", subtitles.as_bytes(), options)?;

    archive
        .finish()
        .map(|cursor| cursor.into_inner())
        .map_err(|_| ApiError::Internal)
}

struct StoryboardExportFile {
    filename: String,
    bytes: Vec<u8>,
}

#[derive(Debug, Serialize)]
struct StoryboardExportManifest<'a> {
    export_type: &'a str,
    shot_count: usize,
    shots: Vec<StoryboardExportManifestShot>,
}

#[derive(Debug, Serialize)]
pub(super) struct StoryboardExportManifestShot {
    storyboard_id: i32,
    order_index: usize,
    storyboard_index: Option<i32>,
    track_id: Option<i32>,
    duration: Option<String>,
    state: Option<String>,
    prompt: Option<String>,
    image_filename: String,
    image_source: Option<String>,
}

impl StoryboardExportManifestShot {
    pub(super) fn from_row(row: &ExportImageSourceRow, order_index: usize) -> Self {
        let extension = row
            .file_path
            .as_deref()
            .and_then(|file_path| parse_storyboard_export_source(file_path, row.numeric_id).ok())
            .map(|source| match source {
                StoryboardExportSource::DataUri { extension, .. } => extension.to_string(),
                StoryboardExportSource::RemoteUrl { url } => {
                    infer_export_extension(&url, None).to_string()
                }
                StoryboardExportSource::AbsolutePath { path } => path
                    .extension()
                    .and_then(|value| value.to_str())
                    .filter(|value| !value.is_empty())
                    .unwrap_or("png")
                    .to_string(),
                StoryboardExportSource::LocalStorage { relative_path } => relative_path
                    .extension()
                    .and_then(|value| value.to_str())
                    .filter(|value| !value.is_empty())
                    .unwrap_or("png")
                    .to_string(),
            })
            .unwrap_or_else(|| "png".to_string());
        Self {
            storyboard_id: row.numeric_id,
            order_index,
            storyboard_index: row.sb_index,
            track_id: row.track_id,
            duration: row.duration.clone(),
            state: row.state.clone(),
            prompt: row.prompt.clone(),
            image_filename: format!("storyboard-{}.{}", row.numeric_id, extension),
            image_source: row.file_path.clone(),
        }
    }
}

#[derive(Debug, Serialize)]
struct StoryboardExportTimeline<'a> {
    export_type: &'a str,
    shot_count: usize,
    total_duration_ms: u64,
    shots: Vec<StoryboardExportTimelineShot>,
}

#[derive(Debug, Serialize)]
struct StoryboardExportTimelineShot {
    storyboard_id: i32,
    order_index: usize,
    storyboard_index: Option<i32>,
    track_id: Option<i32>,
    start_ms: u64,
    end_ms: u64,
    duration_seconds: i32,
    state: Option<String>,
    prompt: Option<String>,
    image_filename: String,
    image_source: Option<String>,
}

fn write_export_text_file(
    archive: &mut zip::ZipWriter<Cursor<Vec<u8>>>,
    filename: &str,
    bytes: &[u8],
    options: FileOptions,
) -> Result<(), ApiError> {
    archive
        .start_file(filename, options)
        .map_err(|_| ApiError::Internal)?;
    archive.write_all(bytes).map_err(|_| ApiError::Internal)
}

pub(super) fn build_storyboard_csv(shots: &[StoryboardExportManifestShot]) -> String {
    let mut out =
        String::from("storyboard_id,order_index,storyboard_index,track_id,duration,state,prompt,image_filename,image_source\n");
    for (index, shot) in shots.iter().enumerate() {
        let fields = [
            shot.storyboard_id.to_string(),
            index.to_string(),
            opt_i32_csv(shot.storyboard_index),
            opt_i32_csv(shot.track_id),
            opt_str_csv(shot.duration.as_deref()),
            opt_str_csv(shot.state.as_deref()),
            opt_str_csv(shot.prompt.as_deref()),
            csv_escape(&shot.image_filename),
            opt_str_csv(shot.image_source.as_deref()),
        ];
        out.push_str(&fields.join(","));
        out.push('\n');
    }
    out
}

fn build_storyboard_timeline(
    shots: &[StoryboardExportManifestShot],
) -> StoryboardExportTimeline<'static> {
    let mut cursor_ms = 0_u64;
    let timeline_shots = shots
        .iter()
        .map(|shot| {
            let duration_seconds = parse_storyboard_duration_seconds(shot.duration.as_deref());
            let start_ms = cursor_ms;
            let end_ms = start_ms + (duration_seconds as u64 * 1000);
            cursor_ms = end_ms;
            StoryboardExportTimelineShot {
                storyboard_id: shot.storyboard_id,
                order_index: shot.order_index,
                storyboard_index: shot.storyboard_index,
                track_id: shot.track_id,
                start_ms,
                end_ms,
                duration_seconds,
                state: shot.state.clone(),
                prompt: shot.prompt.clone(),
                image_filename: shot.image_filename.clone(),
                image_source: shot.image_source.clone(),
            }
        })
        .collect::<Vec<_>>();

    StoryboardExportTimeline {
        export_type: "storyboard_timeline",
        shot_count: timeline_shots.len(),
        total_duration_ms: cursor_ms,
        shots: timeline_shots,
    }
}

pub(super) fn build_storyboard_srt(shots: &[StoryboardExportManifestShot]) -> String {
    let mut out = String::new();
    let mut cursor_ms = 0_u64;
    for (index, shot) in shots.iter().enumerate() {
        let duration_seconds = parse_storyboard_duration_seconds(shot.duration.as_deref());
        let start_ms = cursor_ms;
        let end_ms = start_ms + (duration_seconds as u64 * 1000);
        cursor_ms = end_ms;
        let subtitle = shot
            .prompt
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string)
            .unwrap_or_else(|| format!("Shot {}", shot.storyboard_id));

        out.push_str(&(index + 1).to_string());
        out.push('\n');
        out.push_str(&format!(
            "{} --> {}\n",
            format_srt_timestamp(start_ms),
            format_srt_timestamp(end_ms)
        ));
        out.push_str(&subtitle);
        out.push_str("\n\n");
    }
    out
}

fn parse_storyboard_duration_seconds(value: Option<&str>) -> i32 {
    value
        .and_then(|raw| raw.trim().parse::<i32>().ok())
        .filter(|duration| *duration > 0)
        .unwrap_or(5)
}

fn format_srt_timestamp(total_ms: u64) -> String {
    let hours = total_ms / 3_600_000;
    let minutes = (total_ms % 3_600_000) / 60_000;
    let seconds = (total_ms % 60_000) / 1_000;
    let millis = total_ms % 1_000;
    format!("{hours:02}:{minutes:02}:{seconds:02},{millis:03}")
}

fn opt_i32_csv(value: Option<i32>) -> String {
    value.map(|v| v.to_string()).unwrap_or_default()
}

fn opt_str_csv(value: Option<&str>) -> String {
    value.map(csv_escape).unwrap_or_default()
}

fn csv_escape(value: &str) -> String {
    if value.contains([',', '"', '\n', '\r']) {
        format!("\"{}\"", value.replace('"', "\"\""))
    } else {
        value.to_string()
    }
}

async fn fetch_storyboard_export_bytes(
    state: &AppState,
    owner_user_id: uuid::Uuid,
    numeric_id: i32,
    file_path: &str,
) -> Result<StoryboardExportFile, ApiError> {
    match parse_storyboard_export_source(file_path, numeric_id)? {
        StoryboardExportSource::DataUri { extension, bytes } => Ok(StoryboardExportFile {
            filename: format!("storyboard-{numeric_id}.{extension}"),
            bytes,
        }),
        StoryboardExportSource::RemoteUrl { url } => {
            let resp = state.http_client.get(&url).send().await.map_err(|e| {
                ApiError::BadRequest(format!(
                    "failed to fetch storyboard {numeric_id} image: {e}"
                ))
            })?;
            if !resp.status().is_success() {
                return Err(ApiError::BadRequest(format!(
                    "failed to fetch storyboard {numeric_id} image: upstream status {}",
                    resp.status()
                )));
            }
            let content_type = resp
                .headers()
                .get(header::CONTENT_TYPE)
                .and_then(|v| v.to_str().ok())
                .map(str::to_string);
            let bytes = resp.bytes().await.map_err(|e| {
                ApiError::BadRequest(format!("failed to read storyboard {numeric_id} image: {e}"))
            })?;
            let extension = infer_export_extension(&url, content_type.as_deref());
            Ok(StoryboardExportFile {
                filename: format!("storyboard-{numeric_id}.{extension}"),
                bytes: bytes.to_vec(),
            })
        }
        StoryboardExportSource::AbsolutePath { path } => {
            let bytes = tokio::fs::read(&path).await.map_err(|e| {
                ApiError::BadRequest(format!("failed to read storyboard {numeric_id} file: {e}"))
            })?;
            let extension = path
                .extension()
                .and_then(|s| s.to_str())
                .filter(|s| !s.is_empty())
                .unwrap_or("png");
            Ok(StoryboardExportFile {
                filename: format!("storyboard-{numeric_id}.{extension}"),
                bytes,
            })
        }
        StoryboardExportSource::LocalStorage { relative_path } => {
            let base = state.local_asset_image_dir.as_ref().ok_or_else(|| {
                ApiError::BadRequest(format!(
                    "storyboard {numeric_id} uses local storage but no local image directory is configured"
                ))
            })?;
            let local_path = base.join(owner_user_id.to_string()).join(relative_path);
            let bytes = tokio::fs::read(&local_path).await.map_err(|e| {
                ApiError::BadRequest(format!(
                    "failed to read storyboard {numeric_id} local file: {e}"
                ))
            })?;
            let extension = local_path
                .extension()
                .and_then(|s| s.to_str())
                .filter(|s| !s.is_empty())
                .unwrap_or("png");
            Ok(StoryboardExportFile {
                filename: format!("storyboard-{numeric_id}.{extension}"),
                bytes,
            })
        }
    }
}
