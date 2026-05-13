use base64::Engine as _;

use crate::error::{bad_request_i18n, ApiError};

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
        return Err(bad_request_i18n(
            &format!(
                "art style file_url exceeds max length ({MAX_ART_STYLE_COVER_INPUT_CHARS} chars)"
            ),
            &format!("art style file_url 超过最大长度（{MAX_ART_STYLE_COVER_INPUT_CHARS} 个字符）"),
        ));
    }

    let (mime, b64) = match trimmed.strip_prefix("data:") {
        Some(rest) => {
            let (meta, b64) = rest.split_once(";base64,").ok_or_else(|| {
                bad_request_i18n(
                    "art style file_url data URI must be base64",
                    "art style file_url 的 data URI 必须是 base64",
                )
            })?;
            let mime = match meta.trim().to_ascii_lowercase().as_str() {
                "image/png" => "image/png",
                "image/jpeg" | "image/jpg" => "image/jpeg",
                "image/webp" => "image/webp",
                _ => {
                    return Err(bad_request_i18n(
                        "art style file_url must be png/jpeg/webp data URI, http(s) URL, or API path",
                        "art style file_url 必须是 png/jpeg/webp 的 data URI、http(s) URL 或 API 路径",
                    ));
                }
            };
            (mime, b64.trim())
        }
        None => ("image/jpeg", trimmed),
    };

    let bytes = base64::engine::general_purpose::STANDARD
        .decode(b64.as_bytes())
        .map_err(|_| {
            bad_request_i18n(
                "art style file_url is not valid base64",
                "art style file_url 不是有效的 base64",
            )
        })?;
    if bytes.is_empty() {
        return Err(bad_request_i18n(
            "art style file_url decoded to empty image",
            "art style file_url 解码后为空图片",
        ));
    }
    if bytes.len() > MAX_ART_STYLE_COVER_BYTES {
        return Err(bad_request_i18n(
            &format!(
                "art style cover exceeds max decoded size ({MAX_ART_STYLE_COVER_BYTES} bytes)"
            ),
            &format!("art style cover 超过最大解码大小（{MAX_ART_STYLE_COVER_BYTES} 字节）"),
        ));
    }

    let ext = match mime {
        "image/png" => "png",
        "image/webp" => "webp",
        _ => "jpg",
    };
    Ok(Some(LocalArtStyleCover { bytes, ext }))
}
