use crate::error::ApiError;

pub(in crate::production::workbench::storyboard) fn require_positive_project_script(
    project_id: i32,
    script_id: i32,
) -> Result<(), ApiError> {
    crate::production::workbench::common::require_positive_project_script(project_id, script_id)
}

pub(in crate::production::workbench::storyboard) fn require_positive_scope_ids(
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<(), ApiError> {
    if project_id <= 0 || script_id <= 0 || storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and storyboardId must be positive integers".into(),
        ));
    }
    Ok(())
}

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
