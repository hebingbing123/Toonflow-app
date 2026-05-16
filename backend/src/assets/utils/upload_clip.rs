use base64::Engine as _;

use crate::error::{bad_request_i18n, validate_max_length, ApiError};

use super::constants::MAX_UPLOAD_CLIP_BASE64_LEN;

pub(in crate::assets) fn normalize_upload_clip_data_uri(raw: &str) -> Result<String, ApiError> {
    let input = raw.trim();
    if input.is_empty() {
        return Err(bad_request_i18n(
            "base64Data must not be empty",
            "base64Data 不能为空",
        ));
    }

    let (prefix, payload) = if let Some(rest) = input.strip_prefix("data:") {
        let comma_idx = rest.find(',').ok_or_else(|| {
            bad_request_i18n(
                "base64Data must be a valid data URI",
                "base64Data 必须是有效的 data URI",
            )
        })?;
        let data_uri_prefix = &input[..(5 + comma_idx)];
        if !data_uri_prefix.to_ascii_lowercase().contains(";base64") {
            return Err(bad_request_i18n(
                "base64Data data URI must include ;base64",
                "base64Data 的 data URI 必须包含 ;base64",
            ));
        }
        (Some(data_uri_prefix), &rest[(comma_idx + 1)..])
    } else {
        (None, input)
    };

    if payload.is_empty() {
        return Err(bad_request_i18n(
            "base64Data payload must not be empty",
            "base64Data 的 payload 不能为空",
        ));
    }
    if payload.len() > MAX_UPLOAD_CLIP_BASE64_LEN {
        validate_max_length(payload, MAX_UPLOAD_CLIP_BASE64_LEN, "base64Data")?;
    }
    let decoded = base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| {
            bad_request_i18n(
                "base64Data must be valid base64",
                "base64Data 必须是有效的 base64",
            )
        })?;
    if decoded.is_empty() {
        return Err(bad_request_i18n(
            "base64Data payload must not be empty",
            "base64Data 的 payload 不能为空",
        ));
    }

    Ok(match prefix {
        Some(prefix) => format!("{prefix},{payload}"),
        None => format!("data:application/octet-stream;base64,{payload}"),
    })
}
