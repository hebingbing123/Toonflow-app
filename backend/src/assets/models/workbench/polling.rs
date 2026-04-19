//! 轮询素材生成状态相关类型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct WorkbenchPollingImageAssetsBody {
    pub ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchPollingImageAssetsItem {
    pub id: i32,
    pub state: Option<String>,
    pub file_path: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct WorkbenchPollingPromptAssetsBody {
    pub ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchPollingPromptAssetsItem {
    pub id: i32,
    pub name: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub prompt_state: String,
}
