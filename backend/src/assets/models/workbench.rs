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
pub(crate) struct WorkbenchUploadClipResponse {
    pub message: String,
}

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

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WorkbenchPollingPromptAssetsItem {
    pub id: i32,
    pub name: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub prompt_state: String,
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

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchUploadClipBody {
    pub base64_data: String,
    #[serde(default, alias = "type")]
    pub asset_type: Option<String>,
    pub name: String,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct WorkbenchEmptyBody {}

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
