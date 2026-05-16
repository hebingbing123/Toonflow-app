//! 工作台增删改、上传 clip 等请求体。

use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchUpdateAssetsBody {
    pub id: i32,
    pub name: String,
    pub describe: String,
    #[serde(default)]
    pub remark: Option<String>,
    #[serde(default)]
    pub prompt: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct WorkbenchDeleteAssetsBody {
    pub id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct WorkbenchBatchDeleteAssetsBody {
    pub id: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct WorkbenchDelImageBody {
    pub id: i32,
}

#[derive(Debug, Serialize)]
pub(crate) struct WorkbenchAssetMutationResponse {
    pub message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchUploadClipBody {
    pub base64_data: String,
    #[serde(default, alias = "type")]
    pub asset_type: Option<String>,
    pub name: String,
}

#[derive(Debug, Serialize)]
pub(crate) struct WorkbenchUploadClipResponse {
    pub message: String,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct WorkbenchEmptyBody {}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchAddAssetsBody {
    pub name: String,
    pub describe: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub remark: Option<String>,
    #[serde(default)]
    pub prompt: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchSaveAssetsBody {
    pub id: i32,
    #[serde(default)]
    pub base64: Option<String>,
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub prompt: Option<String>,
    #[serde(default)]
    pub image_id: Option<i32>,
}
