//! 提供商设置 HTTP API 的请求/响应类型。

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct VendorSummaryItem {
    #[serde(flatten)]
    pub(crate) catalog: crate::vendor::catalog::VendorCatalogSummary,
    /// User configuration for this vendor (if any).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) user_config: Option<crate::state::VendorConfigEntry>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct VendorsSummaryResponse {
    pub(crate) vendors: Vec<VendorSummaryItem>,
    /// **`static_catalog`** merged with per-user **`vendor_config`**.
    pub(crate) source: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct VendorModelTestBody {
    pub(crate) model_name: String,
    /// Compat field **`type`**: **`text`** | **`image`** | **`video`**.
    #[serde(rename = "type")]
    pub(crate) kind: String,
    pub(crate) id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct AddVendorBody {
    pub(crate) ts_code: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct UpdateVendorBody {
    pub(crate) id: String,
    /// User-defined display name (optional).
    #[serde(default)]
    pub(crate) display_name: Option<String>,
    /// Selected model IDs from this vendor.
    #[serde(default)]
    pub(crate) selected_models: Vec<String>,
    /// Additional non-sensitive settings key-value pairs.
    #[serde(default)]
    pub(crate) settings: HashMap<String, String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct UpdateVendorResponse {
    pub(crate) vendor_id: String,
    pub(crate) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct DeleteVendorBody {
    pub(crate) id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct EnableVendorBody {
    pub(crate) id: String,
    pub(crate) enable: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct UpdateVendorCodeBody {
    pub(crate) id: String,
    pub(crate) ts_code: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct VendorCodeFromLinkBody {
    pub(crate) link: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct StoreCredentialBody {
    pub(crate) vendor_id: String,
    pub(crate) api_key: Option<String>,
    pub(crate) api_secret: Option<String>,
    pub(crate) api_token: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CredentialResponse {
    pub(crate) vendor_id: String,
    pub(crate) key_hint: Option<String>,
    pub(crate) has_secret: bool,
    pub(crate) has_token: bool,
    pub(crate) message: &'static str,
}
