use crate::error::ApiError;
use base64::Engine;
use std::borrow::Cow;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub(super) enum StoryboardExportSource {
    DataUri {
        extension: &'static str,
        bytes: Vec<u8>,
    },
    RemoteUrl {
        url: String,
    },
    AbsolutePath {
        path: PathBuf,
    },
    LocalStorage {
        relative_path: PathBuf,
    },
}

pub(super) fn parse_storyboard_export_source(
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

    Err(ApiError::BadRequest(format!(
        "storyboard {numeric_id} file_path is not exportable: expected http(s), data URI, or absolute file path"
    )))
}

pub(super) fn infer_export_extension(
    file_path: &str,
    content_type: Option<&str>,
) -> Cow<'static, str> {
    if let Some(ext) = Path::new(file_path)
        .extension()
        .and_then(|s| s.to_str())
        .filter(|s| !s.is_empty())
    {
        return Cow::Owned(ext.to_ascii_lowercase());
    }

    if let Some(content_type) = content_type {
        if let Some(ext) = mime_to_extension(content_type) {
            return Cow::Borrowed(ext);
        }
    }

    Cow::Borrowed("png")
}

fn decode_data_uri_image(input: &str) -> Result<Option<(&'static str, Vec<u8>)>, ApiError> {
    let Some(rest) = input.strip_prefix("data:") else {
        return Ok(None);
    };
    let Some((meta, payload)) = rest.split_once(',') else {
        return Err(ApiError::BadRequest(
            "invalid data URI for storyboard export".into(),
        ));
    };
    if !meta.ends_with(";base64") {
        return Err(ApiError::BadRequest(
            "storyboard export only supports base64 data URIs".into(),
        ));
    }
    let mime = meta.trim_end_matches(";base64");
    let extension = mime_to_extension(mime).ok_or_else(|| {
        ApiError::BadRequest(format!("unsupported storyboard export mime type: {mime}"))
    })?;
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| {
            ApiError::BadRequest("invalid base64 data URI for storyboard export".into())
        })?;
    Ok(Some((extension, bytes)))
}

fn mime_to_extension(mime: &str) -> Option<&'static str> {
    let bare = mime.split(';').next()?.trim().to_ascii_lowercase();
    match bare.as_str() {
        "image/png" => Some("png"),
        "image/jpeg" => Some("jpg"),
        "image/webp" => Some("webp"),
        "image/gif" => Some("gif"),
        "image/svg+xml" => Some("svg"),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::{infer_export_extension, parse_storyboard_export_source, StoryboardExportSource};
    use crate::error::ApiError;

    #[test]
    fn parse_storyboard_export_source_detects_data_uri() {
        let source = parse_storyboard_export_source("data:image/png;base64,Zm9v", 7)
            .expect("data uri source");

        match source {
            StoryboardExportSource::DataUri { extension, bytes } => {
                assert_eq!(extension, "png");
                assert_eq!(bytes, b"foo");
            }
            _ => panic!("expected data uri variant"),
        }
    }

    #[test]
    fn parse_storyboard_export_source_detects_remote_local_and_absolute_sources() {
        let remote =
            parse_storyboard_export_source("https://example.com/image", 8).expect("remote");
        assert!(matches!(remote, StoryboardExportSource::RemoteUrl { .. }));

        let local = parse_storyboard_export_source("/storyboard-local/user/file.webp", 8)
            .expect("local storage");
        match local {
            StoryboardExportSource::LocalStorage { relative_path } => {
                assert_eq!(relative_path, std::path::PathBuf::from("user/file.webp"));
            }
            _ => panic!("expected local storage variant"),
        }

        let absolute =
            parse_storyboard_export_source("/tmp/storyboard.png", 8).expect("absolute path");
        assert!(matches!(
            absolute,
            StoryboardExportSource::AbsolutePath { .. }
        ));
    }

    #[test]
    fn parse_storyboard_export_source_rejects_non_exportable_relative_path() {
        let err = parse_storyboard_export_source("relative/storyboard.png", 9).unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message)
                if message.contains("storyboard 9 file_path is not exportable")
        ));
    }

    #[test]
    fn infer_export_extension_prefers_path_then_content_type_then_png() {
        assert_eq!(
            infer_export_extension("https://example.com/file.JPEG", Some("image/png")),
            "jpeg"
        );
        assert_eq!(
            infer_export_extension("https://example.com/file", Some("image/webp")),
            "webp"
        );
        assert_eq!(
            infer_export_extension("https://example.com/file", None),
            "png"
        );
    }
}
