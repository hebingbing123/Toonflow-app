use crate::vendor::catalog::lookup_vendor_catalog;

pub(super) fn resolve_vendor_probe_targets(
    raw_vendor_id: &str,
) -> (
    Option<crate::vendor::catalog::VendorCatalogLookup>,
    String,
    Vec<String>,
) {
    let vendor = lookup_vendor_catalog(raw_vendor_id);
    let resolved_vendor_id = vendor
        .as_ref()
        .map(|v| v.slug.clone())
        .unwrap_or_else(|| raw_vendor_id.trim().to_ascii_lowercase());
    let mut vendor_candidates = vec![raw_vendor_id.trim().to_string()];
    if vendor_candidates.iter().all(|v| v != &resolved_vendor_id) {
        vendor_candidates.push(resolved_vendor_id.clone());
    }
    if let Some(vendor) = vendor.as_ref() {
        let numeric_id = vendor.numeric_id.to_string();
        if vendor_candidates.iter().all(|v| v != &numeric_id) {
            vendor_candidates.push(numeric_id);
        }
    }
    (vendor, resolved_vendor_id, vendor_candidates)
}

pub(super) fn vendor_probe_credential_source(kind: &str, has_stored_secret: bool) -> &'static str {
    if has_stored_secret {
        "stored_vendor_credential"
    } else if kind == "video" {
        "provider_env"
    } else {
        "server_llm_env"
    }
}
