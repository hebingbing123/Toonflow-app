use base64::Engine as _;

use crate::error::ApiError;

use super::constants::MAX_UPLOAD_CLIP_BASE64_LEN;

pub(in crate::assets) fn normalize_upload_clip_data_uri(raw: &str) -> Result<String, ApiError> {
    let input = raw.trim();
    if input.is_empty() {
        return Err(ApiError::BadRequest("base64Data must not be empty".into()));
    }

    let (prefix, payload) = if let Some(rest) = input.strip_prefix("data:") {
        let comma_idx = rest
            .find(',')
            .ok_or_else(|| ApiError::BadRequest("base64Data must be a valid data URI".into()))?;
        let data_uri_prefix = &input[..(5 + comma_idx)];
        if !data_uri_prefix.to_ascii_lowercase().contains(";base64") {
            return Err(ApiError::BadRequest(
                "base64Data data URI must include ;base64".into(),
            ));
        }
        (Some(data_uri_prefix), &rest[(comma_idx + 1)..])
    } else {
        (None, input)
    };

    if payload.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }
    if payload.len() > MAX_UPLOAD_CLIP_BASE64_LEN {
        return Err(ApiError::BadRequest(format!(
            "base64Data exceeds max length {}",
            MAX_UPLOAD_CLIP_BASE64_LEN
        )));
    }
    let decoded = base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| ApiError::BadRequest("base64Data must be valid base64".into()))?;
    if decoded.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }

    Ok(match prefix {
        Some(prefix) => format!("{prefix},{payload}"),
        None => format!("data:application/octet-stream;base64,{payload}"),
    })
}
