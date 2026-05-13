use base64::Engine;

use crate::error::{bad_request_i18n, ApiError};

use super::mime::mime_to_extension;

pub(super) fn decode_data_uri_image(
    input: &str,
) -> Result<Option<(&'static str, Vec<u8>)>, ApiError> {
    let Some(rest) = input.strip_prefix("data:") else {
        return Ok(None);
    };
    let Some((meta, payload)) = rest.split_once(',') else {
        return Err(bad_request_i18n(
            "invalid data URI for storyboard export",
            "storyboard 导出的 data URI 无效",
        ));
    };
    if !meta.ends_with(";base64") {
        return Err(bad_request_i18n(
            "storyboard export only supports base64 data URIs",
            "storyboard 导出仅支持 base64 data URI",
        ));
    }
    let mime = meta.trim_end_matches(";base64");
    let extension = mime_to_extension(mime).ok_or_else(|| {
        bad_request_i18n(
            &format!("unsupported storyboard export mime type: {mime}"),
            &format!("不支持的 storyboard 导出 MIME 类型: {mime}"),
        )
    })?;
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| {
            bad_request_i18n(
                "invalid base64 data URI for storyboard export",
                "storyboard 导出的 base64 data URI 无效",
            )
        })?;
    Ok(Some((extension, bytes)))
}
