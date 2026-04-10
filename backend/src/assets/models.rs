//! Request/response types for the assets API.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, FromRow};
use uuid::Uuid;

// ── Public response types ────────────────────────────────────────────────────

#[derive(Debug, FromRow, Serialize)]
pub struct AssetRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct ListAssetsQuery {
    /// When set, only assets linked to this script (**`app_script.legacy_id`**) within the project.
    #[serde(default)]
    pub script_legacy_id: Option<i32>,
    /// **`role`**, **`tool`**, or **`scene`** (legacy getAssetsApi **`type`**).
    #[serde(default)]
    pub asset_type: Option<String>,
    /// Case-insensitive substring match on **`name`** (SQL **`ILIKE`**).
    #[serde(default)]
    pub name: Option<String>,
    /// 1-based page when **`limit`** is set (default **1**).
    #[serde(default)]
    pub page: Option<u32>,
    /// Page size; omit for an unpaged list (all matching rows).
    #[serde(default)]
    pub limit: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ListAssetsResponse {
    pub items: Vec<AssetRow>,
    pub total: i64,
}

/// Legacy **`POST /api/cornerScape/getAllAssets`**: top-level project assets.
#[derive(Debug, Serialize)]
pub struct CornerScapeAssetItem {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
    pub metadata: Value,
    pub history_images: Vec<Value>,
}

#[derive(Debug, Serialize)]
pub struct CornerScapeResponse {
    pub items: Vec<CornerScapeAssetItem>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CornerScapeBody {
    #[serde(default)]
    pub types: Option<Vec<String>>,
}

#[derive(Debug, FromRow)]
pub(super) struct CornerScapeDbRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
    pub metadata: SqlxJson<Value>,
    pub history_images: SqlxJson<Value>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CreateAssetBody {
    pub name: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub description: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct PatchAssetBody {
    #[serde(default)]
    pub name: Option<Value>,
    #[serde(default)]
    pub description: Option<Value>,
    #[serde(default)]
    pub asset_type: Option<Value>,
    #[serde(default)]
    pub cover_legacy_image_id: Option<Value>,
}

/// One **`app_asset_image`** row.
#[derive(Debug, FromRow, Serialize)]
pub struct AssetImageRow {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub sort_index: i32,
    pub file_path: Option<String>,
    pub state: Option<String>,
    pub legacy_image_id: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct AssetImageListItem {
    #[serde(flatten)]
    pub row: AssetImageRow,
    pub selected: bool,
}

#[derive(Debug, Serialize)]
pub struct ListAssetImagesResponse {
    pub cover_legacy_image_id: Option<i32>,
    pub items: Vec<AssetImageListItem>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CreateAssetImageBody {
    #[serde(default)]
    pub file_path: Option<String>,
    #[serde(default)]
    pub state: Option<String>,
    #[serde(default)]
    pub sort_index: Option<i32>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct PatchAssetImageBody {
    #[serde(default)]
    pub file_path: Option<Value>,
    #[serde(default)]
    pub state: Option<Value>,
    #[serde(default)]
    pub sort_index: Option<Value>,
}

#[derive(Debug, FromRow)]
pub(super) struct AssetImageFileSource {
    pub file_path: Option<String>,
    pub metadata: SqlxJson<Value>,
}

// ── Legacy request/response types ───────────────────────────────────────────

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyGetImageBody {
    pub assets_id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyUploadClipBody {
    pub project_id: i32,
    pub base64_data: String,
    #[serde(default, alias = "type")]
    pub asset_type: Option<String>,
    pub name: String,
}

#[derive(Debug, Serialize)]
pub(super) struct LegacyUploadClipResponse {
    pub message: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyAddAssetsBody {
    pub name: String,
    pub describe: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub project_id: i32,
    #[serde(default)]
    pub remark: Option<String>,
    #[serde(default)]
    pub prompt: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyUpdateAssetsBody {
    pub id: i32,
    pub name: String,
    pub describe: String,
    #[serde(default)]
    pub remark: Option<String>,
    #[serde(default)]
    pub prompt: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacySaveAssetsBody {
    pub id: i32,
    pub project_id: i32,
    #[serde(default)]
    pub base64: Option<String>,
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub prompt: Option<String>,
    #[serde(default)]
    pub image_id: Option<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyDeleteAssetsBody {
    pub id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyBatchDeleteAssetsBody {
    pub id: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyDelImageBody {
    pub id: i32,
}

#[derive(Debug, Serialize)]
pub(super) struct LegacyAssetMutationResponse {
    pub message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyPollingImageAssetsBody {
    pub ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyPollingImageAssetsItem {
    pub id: i32,
    pub state: Option<String>,
    pub file_path: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyPollingPromptAssetsBody {
    pub ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyGetMaterialDataBody {
    pub project_id: i32,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyMaterialAssetItem {
    pub id: i32,
    pub name: String,
    pub file_path: String,
    #[serde(rename = "type")]
    pub asset_type: String,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyMaterialVideoItem {
    pub id: i32,
    pub file_path: String,
    pub video_track_id: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetMaterialDataResponse {
    pub data: Vec<LegacyMaterialAssetItem>,
    pub video: Vec<LegacyMaterialVideoItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyBatchGenerationDataBody {
    pub project_id: i32,
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub name: Option<String>,
    pub page: i32,
    pub limit: i32,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyBatchGenerationAssetItem {
    pub id: i32,
    pub name: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub description: Option<String>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyBatchGenerationDataResponse {
    pub data: Vec<LegacyBatchGenerationAssetItem>,
    pub total: i64,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyPollingPromptAssetsItem {
    pub id: i32,
    pub name: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub prompt_state: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetImageTempAssetItem {
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
pub(super) struct LegacyGetImageResponse {
    pub id: i32,
    pub image_id: Option<i32>,
    pub temp_assets: Vec<LegacyGetImageTempAssetItem>,
}

#[derive(Debug, FromRow)]
pub(super) struct LegacyGetImageAssetRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub asset_type: String,
    pub metadata: SqlxJson<Value>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyGetAssetsApiBody {
    pub project_id: i32,
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
pub(super) struct LegacyGetAssetsApiChildItem {
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
pub(super) struct LegacyGetAssetsApiParentItem {
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
    pub son_assets: Vec<LegacyGetAssetsApiChildItem>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetAssetsApiResponse {
    pub data: Vec<LegacyGetAssetsApiParentItem>,
    pub total: i64,
}

#[derive(Debug, FromRow)]
pub(super) struct LegacyGetAssetsApiDbRow {
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

// ── Internal helpers ─────────────────────────────────────────────────────────

#[derive(Debug, FromRow)]
pub(crate) struct LegacyOwnedAssetMetaRow {
    pub id: Uuid,
    pub metadata: SqlxJson<Value>,
    pub project_legacy_id: i32,
}

#[derive(Debug, FromRow)]
pub(super) struct AssetPatchCurrent {
    pub id: Uuid,
    pub name: String,
    pub asset_type: String,
    pub description: Option<String>,
    pub metadata: SqlxJson<Value>,
}
