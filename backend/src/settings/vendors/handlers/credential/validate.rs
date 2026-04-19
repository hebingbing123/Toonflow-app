use crate::error::ApiError;

pub(super) fn require_nonempty_vendor_id(vendor_id: &str) -> Result<&str, ApiError> {
    let vendor_id = vendor_id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("vendorId must be non-empty".into()));
    }
    Ok(vendor_id)
}
