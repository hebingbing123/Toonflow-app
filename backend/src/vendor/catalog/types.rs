//! 静态模型目录 HTTP 与跨模块 DTO。

use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct PatchTextModelDefaultBody {
    /// Composite id `{vendor_id}:{model_name}` — must exist in the catalog.
    /// Pass `null` to reset to server default.
    pub(crate) model_id: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub(crate) struct ModelListEntry {
    /// Vendor id (Electron-era `o_vendorConfig.id` analogue).
    pub(crate) id: i32,
    pub(crate) label: String,
    pub(crate) value: String,
    #[serde(rename = "type")]
    pub(crate) kind: String,
    /// Vendor display name.
    pub(crate) name: String,
    /// Composite id `{vendor_id}:{model_name}`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) model_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) pricing: Option<super::pricing::ModelPricingPublic>,
}

#[derive(Debug, Serialize, ToSchema)]
pub(crate) struct ModelDetailResponse {
    pub(crate) vendor_id: i32,
    pub(crate) vendor_name: String,
    pub(crate) name: String,
    pub(crate) model_name: String,
    #[serde(rename = "type")]
    pub(crate) kind: String,
    pub(crate) model_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) pricing: Option<super::pricing::ModelPricingPublic>,
}

#[derive(Debug, Deserialize, IntoParams)]
pub(crate) struct ListQuery {
    /// One of `text`, `image`, `video`, `all`. When omitted, treated as `all`.
    /// `all` excludes `video` entries (Electron-era `getModelList` behaviour).
    #[serde(default, rename = "type")]
    pub(crate) filter: Option<String>,
    /// When `true`, attach `model_id` and `pricing` from `model_pricing.json`.
    #[serde(default)]
    pub(crate) include_pricing: Option<bool>,
}

#[derive(Debug, Deserialize, IntoParams)]
pub(crate) struct DetailQuery {
    /// Composite id: `{vendor_id}:{model_name}` (e.g. `1:gpt-4o-mini`).
    pub(crate) model_id: String,
    #[serde(default)]
    pub(crate) include_pricing: Option<bool>,
}

#[derive(Debug, Serialize)]
pub(crate) struct TextModelDefaultResponse {
    /// Historical **`POST /api/setting/getTextModel`** returned this string as envelope **`data`** (stub).
    pub(crate) stub_placeholder: &'static str,
    /// Composite id for **`GET /api/v1/models/detail?model_id=`**.
    pub(crate) default_model_id: String,
}

/// One vendor row for **`GET /api/v1/settings/vendors/summary`** (no API keys; not **`o_vendorConfig`**).
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct VendorCatalogSummary {
    pub(crate) id: i32,
    pub(crate) name: String,
    pub(crate) model_count: usize,
    /// Sorted unique **`type`** values from embedded catalog models.
    pub(crate) model_kinds: Vec<String>,
}

#[derive(Debug, Clone)]
pub(crate) struct VendorCatalogLookup {
    pub(crate) numeric_id: i32,
    pub(crate) name: String,
    pub(crate) slug: String,
}
