//! Request/response types for vendor settings HTTP API.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct VendorSummaryItem {
    #[serde(flatten)]
    pub(super) catalog: crate::vendor::catalog::VendorCatalogSummary,
    /// User configuration for this vendor (if any).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(super) user_config: Option<crate::state::VendorConfigEntry>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct VendorsSummaryResponse {
    pub(super) vendors: Vec<VendorSummaryItem>,
    /// **`static_catalog`** merged with per-user **`vendor_config`**.
    pub(super) source: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct VendorModelTestBody {
    pub(super) model_name: String,
    /// Legacy field **`type`**: **`text`** | **`image`** | **`video`**.
    #[serde(rename = "type")]
    pub(super) kind: String,
    pub(super) id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct AddVendorBody {
    pub(super) ts_code: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct UpdateVendorBody {
    pub(super) id: String,
    /// User-defined display name (optional).
    #[serde(default)]
    pub(super) display_name: Option<String>,
    /// Selected model IDs from this vendor.
    #[serde(default)]
    pub(super) selected_models: Vec<String>,
    /// Additional non-sensitive settings key-value pairs.
    #[serde(default)]
    pub(super) settings: HashMap<String, String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct UpdateVendorResponse {
    pub(super) vendor_id: String,
    pub(super) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct DeleteVendorBody {
    pub(super) id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct EnableVendorBody {
    pub(super) id: String,
    pub(super) enable: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct UpdateVendorCodeBody {
    pub(super) id: String,
    pub(super) ts_code: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct VendorCodeFromLinkBody {
    pub(super) link: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct StoreCredentialBody {
    pub(super) vendor_id: String,
    pub(super) api_key: Option<String>,
    pub(super) api_secret: Option<String>,
    pub(super) api_token: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct CredentialResponse {
    pub(super) vendor_id: String,
    pub(super) key_hint: Option<String>,
    pub(super) has_secret: bool,
    pub(super) has_token: bool,
    pub(super) message: &'static str,
}
