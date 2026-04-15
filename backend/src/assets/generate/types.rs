#![allow(dead_code)]

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub(super) enum AssetGenKind {
    #[serde(rename = "role")]
    Role,
    #[serde(rename = "scene")]
    Scene,
    #[serde(rename = "tool")]
    Tool,
    #[serde(rename = "storyboard")]
    Storyboard,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct GenerateAssetsBody {
    pub(super) project_id: i32,
    pub(super) model: String,
    pub(super) resolution: String,
    pub(super) id: i32,
    #[serde(rename = "type")]
    pub(super) asset_type: AssetGenKind,
    pub(super) name: String,
    pub(super) prompt: String,
    #[serde(default)]
    pub(super) base64: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct PolishAssetsPromptBody {
    pub(super) assets_id: i32,
    pub(super) project_id: i32,
    #[serde(rename = "type")]
    pub(super) asset_type: String,
    pub(super) name: String,
    pub(super) describe: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct BatchGenItem {
    pub(super) id: i32,
    #[serde(rename = "type")]
    pub(super) asset_type: AssetGenKind,
    pub(super) name: String,
    pub(super) prompt: String,
    #[serde(default)]
    pub(super) base64: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct BatchGenerateImageAssetsBody {
    pub(super) project_id: i32,
    pub(super) model: String,
    pub(super) resolution: String,
    /// When set, every **`items[].id`** must be an **`app_asset.numeric_id`** linked to this script
    /// (**`app_script_asset`**) under the same owned **`project_id`** (numeric).
    #[serde(default)]
    pub(super) script_id: Option<i32>,
    #[serde(default)]
    pub(super) concurrent_count: Option<i32>,
    pub(super) items: Vec<BatchGenItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct BatchPolishItem {
    pub(super) assets_id: i32,
    #[serde(rename = "type")]
    pub(super) asset_type: String,
    pub(super) name: String,
    pub(super) describe: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct BatchPolishAssetsPromptBody {
    pub(super) project_id: i32,
    #[serde(default)]
    pub(super) concurrent_count: Option<i32>,
    pub(super) items: Vec<BatchPolishItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct CancelGenerateBody {
    pub(super) id: i32,
}
