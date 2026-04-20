use crate::error::ApiError;

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
