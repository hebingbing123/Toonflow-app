//! 提供商配置模块。
//!
//! 每个用户的提供商配置（非敏感：启用的提供商、模型选择）。
//! API 密钥（inputValues）故意不存储在此处；使用服务器环境或 Vault。
//! 不支持 TypeScript 代码（tsCode）执行。

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Per-vendor configuration (non-sensitive fields only).
/// API keys are intentionally excluded; they should be configured via server env or vault.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct VendorConfigEntry {
    /// Vendor ID from the static catalog.
    pub vendor_id: String,
    /// User-defined display name (optional override).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub display_name: Option<String>,
    /// Whether this vendor is enabled for this user.
    #[serde(default)]
    pub enabled: bool,
    /// Selected model IDs from this vendor (subset of vendor's available models).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub selected_models: Vec<String>,
    /// Additional non-sensitive config key-value pairs (UI settings, etc).
    /// API keys must NOT be stored here.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub settings: HashMap<String, String>,
}

/// User vendor configuration stored in `app_user_profile.vendor_config`.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct VendorConfig {
    /// Per-vendor configurations keyed by vendor_id.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub vendors: HashMap<String, VendorConfigEntry>,
    /// Default vendor ID for text generation (if user has preference).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_text_vendor_id: Option<String>,
    /// Default vendor ID for image generation (if user has preference).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_image_vendor_id: Option<String>,
    /// Default vendor ID for video generation (if user has preference).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_video_vendor_id: Option<String>,
}

impl VendorConfig {
    /// Get or create a mutable entry for a vendor.
    pub fn get_or_insert_vendor(&mut self, vendor_id: &str) -> &mut VendorConfigEntry {
        self.vendors
            .entry(vendor_id.to_string())
            .or_insert_with(|| VendorConfigEntry {
                vendor_id: vendor_id.to_string(),
                display_name: None,
                enabled: false,
                selected_models: Vec::new(),
                settings: HashMap::new(),
            })
    }

    /// Get a vendor entry if it exists.
    pub fn get_vendor(&self, vendor_id: &str) -> Option<&VendorConfigEntry> {
        self.vendors.get(vendor_id)
    }

    /// Set vendor enabled state.
    pub fn set_vendor_enabled(&mut self, vendor_id: &str, enabled: bool) {
        let entry = self.get_or_insert_vendor(vendor_id);
        entry.enabled = enabled;
    }
}
