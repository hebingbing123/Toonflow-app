use crate::error::{validate_non_empty_string, ApiError};

pub(super) fn require_nonempty_vendor_id(vendor_id: &str) -> Result<&str, ApiError> {
    let vendor_id = vendor_id.trim();
    validate_non_empty_string(vendor_id, "vendorId")?;
    Ok(vendor_id)
}
