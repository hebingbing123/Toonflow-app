use std::path::{Path, PathBuf};

use crate::error::{bad_request_i18n, ApiError};

use super::data_uri::decode_data_uri_image;
use super::types::StoryboardExportSource;

pub(in crate::production::workbench::storyboard_ops) fn parse_storyboard_export_source(
    file_path: &str,
    numeric_id: i32,
) -> Result<StoryboardExportSource, ApiError> {
    if let Some((extension, bytes)) = decode_data_uri_image(file_path)? {
        return Ok(StoryboardExportSource::DataUri { extension, bytes });
    }

    if file_path.starts_with("http://") || file_path.starts_with("https://") {
        return Ok(StoryboardExportSource::RemoteUrl {
            url: file_path.to_string(),
        });
    }

    if let Some(rest) = file_path.strip_prefix("/storyboard-local/") {
        return Ok(StoryboardExportSource::LocalStorage {
            relative_path: PathBuf::from(rest),
        });
    }

    let path = Path::new(file_path);
    if path.is_absolute() {
        return Ok(StoryboardExportSource::AbsolutePath {
            path: path.to_path_buf(),
        });
    }

    Err(bad_request_i18n(
        &format!(
            "storyboard {numeric_id} file_path is not exportable: expected http(s), data URI, or absolute file path"
        ),
        &format!(
            "storyboard {numeric_id} 的 file_path 不可导出：需要 http(s)、data URI 或绝对文件路径"
        ),
    ))
}
