use crate::error::{bad_request_i18n, ApiError};

pub(super) fn validate_polling_ids(ids: &[i32]) -> Result<(), ApiError> {
    if !ids.is_empty() {
        if ids.len() > 200 {
            return Err(bad_request_i18n(
                "ids must have at most 200 rows",
                "ids 最多只能包含 200 条",
            ));
        }
        if ids.iter().any(|id| *id <= 0) {
            return Err(bad_request_i18n(
                "each ids[] must be positive",
                "ids[] 的每一项都必须为正数",
            ));
        }
    }
    Ok(())
}
