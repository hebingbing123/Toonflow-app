use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetDataItem {
    pub(super) id: i32,
    pub(super) name: String,
    #[serde(rename = "type")]
    pub(super) asset_type: String,
    pub(super) describe: Option<String>,
    pub(super) cover_numeric_image_id: Option<i32>,
    pub(super) created_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetsDataResponse {
    pub(super) assets: Vec<AssetDataItem>,
    pub(super) total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GetAssetsDataBody {
    pub(super) project_id: i32,
    pub(super) script_id: i32,
    #[serde(default)]
    pub(super) asset_type: Option<String>,
    #[serde(default)]
    pub(super) limit: Option<i64>,
    #[serde(default)]
    pub(super) offset: Option<i64>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct AssetsPollingImageBody {
    pub(super) project_id: i32,
    pub(super) script_id: i32,
    pub(super) asset_ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetImageStatus {
    pub(super) asset_id: i32,
    pub(super) image_count: i64,
    pub(super) latest_state: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AssetsPollingImageResponse {
    pub(super) statuses: Vec<AssetImageStatus>,
}
