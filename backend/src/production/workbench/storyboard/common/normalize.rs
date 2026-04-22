use crate::error::ApiError;

pub(in crate::production::workbench::storyboard) const DEFAULT_STORYBOARD_DURATION: i32 = 5;

pub(in crate::production::workbench::storyboard) fn normalize_storyboard_prompt(
    prompt: &str,
) -> Result<String, ApiError> {
    let prompt = prompt.trim();
    if prompt.is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }
    Ok(prompt.to_string())
}

pub(in crate::production::workbench::storyboard) fn normalize_storyboard_image_url(
    image_url: &str,
) -> Result<String, ApiError> {
    let image_url = image_url.trim();
    if image_url.is_empty() {
        return Err(ApiError::BadRequest("imageUrl must not be empty".into()));
    }
    Ok(image_url.to_string())
}

pub(in crate::production::workbench::storyboard) fn normalize_storyboard_duration(
    duration: Option<i32>,
) -> Result<i32, ApiError> {
    let duration = duration.unwrap_or(DEFAULT_STORYBOARD_DURATION);
    if duration <= 0 {
        return Err(ApiError::BadRequest(
            "duration must be a positive integer".into(),
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
