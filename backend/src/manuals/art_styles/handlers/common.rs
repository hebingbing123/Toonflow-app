use crate::error::ApiError;

pub(super) fn trim_opt(s: Option<String>) -> Option<String> {
    s.map(|v| v.trim().to_owned()).filter(|s| !s.is_empty())
}

pub(super) fn require_positive_numeric_id(numeric_id: i32) -> Result<(), ApiError> {
    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }
    Ok(())
}
