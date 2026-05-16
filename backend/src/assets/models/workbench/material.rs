//! 工作台素材列表（资产 + 视频轨）类型。

use serde::Serialize;
use sqlx::FromRow;

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchMaterialAssetItem {
    pub id: i32,
    pub name: String,
    pub file_path: String,
    #[serde(rename = "type")]
    pub asset_type: String,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchMaterialVideoItem {
    pub id: i32,
    pub file_path: String,
    pub video_track_id: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchGetMaterialDataResponse {
    pub data: Vec<WorkbenchMaterialAssetItem>,
    pub video: Vec<WorkbenchMaterialVideoItem>,
}
