use crate::error::ApiError;

pub(in crate::production::workbench) fn validate_positive_id(
    name: &str,
    id: i32,
) -> Result<(), ApiError> {
    if id <= 0 {
        return Err(ApiError::BadRequest(format!(
            "{name} must be a positive integer"
        )));
    }
    Ok(())
}
