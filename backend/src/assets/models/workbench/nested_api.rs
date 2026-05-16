//! 父子资产树 API（`get-assets-api` / nested）类型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchNestedAssetsBody {
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub page: Option<i32>,
    #[serde(default)]
    pub limit: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchGetAssetsApiChildItem {
    pub id: i32,
    pub project_id: i32,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub name: String,
    pub assets_id: Option<i32>,
    pub image_id: Option<i32>,
    pub file_path: Option<String>,
    pub state: Option<String>,
    pub error_reason: Option<String>,
    pub src: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchGetAssetsApiParentItem {
    pub id: i32,
    pub project_id: i32,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub name: String,
    pub assets_id: Option<i32>,
    pub image_id: Option<i32>,
    pub file_path: Option<String>,
    pub state: Option<String>,
    pub error_reason: Option<String>,
    pub src: Option<String>,
    pub son_assets: Vec<WorkbenchGetAssetsApiChildItem>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchGetAssetsApiResponse {
    pub data: Vec<WorkbenchGetAssetsApiParentItem>,
    pub total: i64,
}

#[derive(Debug, FromRow)]
pub(crate) struct WorkbenchGetAssetsApiDbRow {
    pub id: i32,
    pub project_id: Option<i32>,
    pub asset_type: String,
    pub name: String,
    pub assets_id: Option<i32>,
    pub image_id: Option<i32>,
    pub file_path: Option<String>,
    pub state: Option<String>,
    pub error_reason: Option<String>,
}
