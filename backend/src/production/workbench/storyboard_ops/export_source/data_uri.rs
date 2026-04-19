use base64::Engine;

use crate::error::ApiError;

use super::mime::mime_to_extension;

pub(super) fn decode_data_uri_image(
    input: &str,
) -> Result<Option<(&'static str, Vec<u8>)>, ApiError> {
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
