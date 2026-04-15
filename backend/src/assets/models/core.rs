use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, FromRow};
use uuid::Uuid;

/// `app_asset` 实体的数据库行。
#[derive(Debug, FromRow, Serialize)]
pub struct AssetRow {
    pub id: Uuid,
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
}

/// 项目中列出资产的查询参数。
#[derive(Debug, Deserialize)]
pub struct ListAssetsQuery {
    #[serde(default, rename = "script_numeric_id")]
    pub script_numeric_id: Option<i32>,
    #[serde(default)]
    pub asset_type: Option<String>,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub page: Option<u32>,
    #[serde(default)]
    pub limit: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ListAssetsResponse {
    pub items: Vec<AssetRow>,
    pub total: i64,
}

#[derive(Debug, Serialize)]
pub struct CornerScapeAssetItem {
    pub id: Uuid,
    #[serde(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
    pub metadata: Value,
    pub history_images: Vec<Value>,
}

#[derive(Debug, Serialize)]
pub(crate) struct CornerScapeResponse {
    pub items: Vec<CornerScapeAssetItem>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct CornerScapeBody {
    #[serde(default)]
    pub types: Option<Vec<String>>,
}

#[derive(Debug, FromRow)]
pub(crate) struct CornerScapeDbRow {
    pub id: Uuid,
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
    pub metadata: SqlxJson<Value>,
    pub history_images: SqlxJson<Value>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct CreateAssetBody {
    pub name: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub description: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct PatchAssetBody {
    #[serde(default)]
    pub name: Option<Value>,
    #[serde(default)]
    pub description: Option<Value>,
    #[serde(default)]
    pub asset_type: Option<Value>,
    #[serde(default, rename = "cover_numeric_image_id")]
    pub cover_numeric_image_id: Option<Value>,
}

#[derive(Debug, FromRow, Serialize)]
pub struct AssetImageRow {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub sort_index: i32,
    pub file_path: Option<String>,
    pub state: Option<String>,
    #[serde(rename = "numeric_image_id")]
    #[sqlx(rename = "numeric_image_id")]
    pub numeric_image_id: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct AssetImageListItem {
    #[serde(flatten)]
    pub row: AssetImageRow,
    pub selected: bool,
}

#[derive(Debug, Serialize)]
pub struct ListAssetImagesResponse {
    #[serde(rename = "cover_numeric_image_id")]
    pub cover_numeric_image_id: Option<i32>,
    pub items: Vec<AssetImageListItem>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct CreateAssetImageBody {
    #[serde(default)]
    pub file_path: Option<String>,
    #[serde(default)]
    pub state: Option<String>,
    #[serde(default)]
    pub sort_index: Option<i32>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct PatchAssetImageBody {
    #[serde(default)]
    pub file_path: Option<Value>,
    #[serde(default)]
    pub state: Option<Value>,
    #[serde(default)]
    pub sort_index: Option<Value>,
}

#[derive(Debug, FromRow)]
pub(crate) struct AssetImageFileSource {
    pub file_path: Option<String>,
    pub metadata: SqlxJson<Value>,
}

#[derive(Debug, FromRow)]
pub(crate) struct WorkbenchOwnedAssetMetaRow {
    pub id: Uuid,
    pub metadata: SqlxJson<Value>,
}

#[derive(Debug, FromRow)]
pub(crate) struct AssetPatchCurrent {
    pub id: Uuid,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub metadata: SqlxJson<Value>,
}
