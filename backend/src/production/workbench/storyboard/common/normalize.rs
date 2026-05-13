use crate::error::{bad_request_i18n, validate_non_empty_string, ApiError};

pub(in crate::production::workbench::storyboard) const DEFAULT_STORYBOARD_DURATION: i32 = 5;

pub(in crate::production::workbench::storyboard) fn normalize_storyboard_prompt(
    prompt: &str,
) -> Result<String, ApiError> {
    let prompt = prompt.trim();
    validate_non_empty_string(prompt, "prompt")?;
    Ok(prompt.to_string())
}

pub(in crate::production::workbench::storyboard) fn normalize_storyboard_image_url(
    image_url: &str,
) -> Result<String, ApiError> {
    let image_url = image_url.trim();
    validate_non_empty_string(image_url, "imageUrl")?;
    Ok(image_url.to_string())
}

pub(in crate::production::workbench::storyboard) fn normalize_storyboard_duration(
    duration: Option<i32>,
) -> Result<i32, ApiError> {
    let duration = duration.unwrap_or(DEFAULT_STORYBOARD_DURATION);
    if duration <= 0 {
        return Err(bad_request_i18n(
            "duration must be a positive integer",
            "duration 必须是正整数",
        ));
    }
    Ok(duration)
}

pub(in crate::production::workbench::storyboard) fn validate_storyboard_duration(
    duration: Option<i32>,
) -> Result<Option<i32>, ApiError> {
    duration
        .map(|value| normalize_storyboard_duration(Some(value)))
        .transpose()
}
