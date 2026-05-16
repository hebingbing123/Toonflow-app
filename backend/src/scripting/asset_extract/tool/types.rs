//! LLM 工具响应反序列化类型与过滤后的条目。

use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct ToolResultPayload {
    #[serde(default)]
    pub(crate) new_assets: Vec<NewAssetItem>,
    #[serde(default, alias = "existingAssetRefs")]
    pub(crate) existing_asset_refs: Vec<ExistingRefItem>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct NewAssetItem {
    pub(crate) name: String,
    pub(crate) desc: String,
    #[serde(rename = "type")]
    pub(crate) asset_type: String,
    #[serde(default, alias = "scriptIds", alias = "script_numeric_ids")]
    pub(crate) script_numeric_ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ExistingRefItem {
    pub(crate) name: String,
    #[serde(default, alias = "scriptIds", alias = "script_numeric_ids")]
    pub(crate) script_numeric_ids: Vec<i32>,
}

pub(crate) struct NewAssetItemFiltered {
    pub(crate) name: String,
    pub(crate) desc: String,
    pub(crate) asset_type: String,
    pub(crate) script_numeric_ids: Vec<i32>,
}

pub(crate) struct ExistingRefItemFiltered {
    pub(crate) name: String,
    pub(crate) script_numeric_ids: Vec<i32>,
}
