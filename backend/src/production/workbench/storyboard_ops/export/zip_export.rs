//! 分镜导出：拉取字节并写入 zip。

use std::io::{Cursor, Write};

use axum::http::header;
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

    for row in rows {
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

    archive
        .finish()
        .map(|cursor| cursor.into_inner())
        .map_err(|_| ApiError::Internal)
}

struct StoryboardExportFile {
    filename: String,
    bytes: Vec<u8>,
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
