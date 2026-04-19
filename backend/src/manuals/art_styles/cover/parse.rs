use base64::Engine as _;

use crate::error::ApiError;

use super::super::types::{MAX_ART_STYLE_COVER_BYTES, MAX_ART_STYLE_COVER_INPUT_CHARS};
use super::types::LocalArtStyleCover;

fn is_http_url(s: &str) -> bool {
    s.starts_with("http://") || s.starts_with("https://")
}

pub(crate) fn parse_uploaded_cover(raw: &str) -> Result<Option<LocalArtStyleCover>, ApiError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() || is_http_url(trimmed) || trimmed.starts_with('/') {
        return Ok(None);
    }
    if trimmed.len() > MAX_ART_STYLE_COVER_INPUT_CHARS {
        return Err(ApiError::BadRequest(format!(
            "art style file_url exceeds max length ({MAX_ART_STYLE_COVER_INPUT_CHARS} chars)"
        )));
    }

    let (mime, b64) = match trimmed.strip_prefix("data:") {
        Some(rest) => {
            let (meta, b64) = rest.split_once(";base64,").ok_or_else(|| {
                ApiError::BadRequest("art style file_url data URI must be base64".into())
            })?;
            let mime = match meta.trim().to_ascii_lowercase().as_str() {
                "image/png" => "image/png",
                "image/jpeg" | "image/jpg" => "image/jpeg",
                "image/webp" => "image/webp",
                _ => {
                    return Err(ApiError::BadRequest(
                        "art style file_url must be png/jpeg/webp data URI, http(s) URL, or API path"
                            .into(),
                    ));
                }
            };
            (mime, b64.trim())
        }
        None => ("image/jpeg", trimmed),
    };

    let bytes = base64::engine::general_purpose::STANDARD
        .decode(b64.as_bytes())
        .map_err(|_| ApiError::BadRequest("art style file_url is not valid base64".into()))?;
    if bytes.is_empty() {
        return Err(ApiError::BadRequest(
            "art style file_url decoded to empty image".into(),
        ));
    }
    if bytes.len() > MAX_ART_STYLE_COVER_BYTES {
        return Err(ApiError::BadRequest(format!(
            "art style cover exceeds max decoded size ({MAX_ART_STYLE_COVER_BYTES} bytes)"
        )));
    }

    let ext = match mime {
        "image/png" => "png",
        "image/webp" => "webp",
        _ => "jpg",
    };
    Ok(Some(LocalArtStyleCover { bytes, ext }))
}
