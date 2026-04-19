//! 工作台「取图 / bundle」相关类型。

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, FromRow};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchGetImageBody {
    pub assets_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchGetImageTempAssetItem {
    pub id: Option<i32>,
    pub image_uuid: Uuid,
    pub file_path: String,
    pub assets_id: i32,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub state: Option<String>,
    pub selected: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchGetImageResponse {
    pub id: i32,
    pub image_id: Option<i32>,
    pub temp_assets: Vec<WorkbenchGetImageTempAssetItem>,
}

#[derive(Debug, FromRow)]
pub(crate) struct WorkbenchGetImageAssetRow {
    pub id: Uuid,
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub asset_type: String,
    pub metadata: SqlxJson<Value>,
}
