use crate::error::ApiError;

pub(super) fn validate_polling_ids(ids: &[i32]) -> Result<(), ApiError> {
    if !ids.is_empty() {
        if ids.len() > 200 {
            return Err(ApiError::BadRequest(
                "ids must have at most 200 rows".into(),
            ));
        }
        if ids.iter().any(|id| *id <= 0) {
            return Err(ApiError::BadRequest("each ids[] must be positive".into()));
        }
    }
    Ok(())
}
