//! 批量生成列表查询类型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchBatchGenerationAssetItem {
    pub id: i32,
    pub name: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchBatchGenerationDataResponse {
    pub data: Vec<WorkbenchBatchGenerationAssetItem>,
    pub total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchBatchGenerationDataBody {
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub name: Option<String>,
    pub page: i32,
    pub limit: i32,
}
