//! 资产 API 的请求/响应类型。

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, FromRow};
use uuid::Uuid;

// ── Public response types ────────────────────────────────────────────────────

/// `app_asset` 实体的数据库行。
///
/// 表示项目范围内的资产（角色、工具或场景）及其核心元数据。
/// 由 CRUD 列表/详情端点和遗留资产 API 返回。
#[derive(Debug, FromRow, Serialize)]
pub struct AssetRow {
    /// 内部 UUID 主键 (`app_asset.id`)。
    pub id: Uuid,
    /// 向客户端暴露的稳定整数 ID（`app_asset.legacy_id` 列；JSON 键 **`numeric_id`**）。
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "legacy_id")]
    pub numeric_id: i32,
    /// 资产显示名称。
    pub name: String,
    /// 资产分类：role、tool 或 scene。
    pub asset_type: String,
    /// 可选的人类可读描述或提示词文本。
    pub description: Option<String>,
    /// 创建时间戳（Unix 纪元以来的毫秒，如果有记录）。
    pub create_time_ms: Option<i64>,
}

/// 项目中列出资产的查询参数。
///
/// 支持按脚本关联、资产类型和名称子串过滤。
/// 分页使用从 1 开始的页码，可选每页大小限制。
#[derive(Debug, Deserialize)]
pub struct ListAssetsQuery {
    /// 设置时，仅返回项目中关联到此脚本 (`app_script.legacy_id`) 的资产。
    #[serde(default, rename = "script_numeric_id")]
    pub script_numeric_id: Option<i32>,
    /// role、tool 或 scene（遗留 getAssetsApi 的 type）。
    #[serde(default)]
    pub asset_type: Option<String>,
    /// 对 name 的不区分大小写子串匹配 (SQL ILIKE)。
    #[serde(default)]
    pub name: Option<String>,
    /// 设置 limit 时的页码（从 1 开始，默认 1）。
    #[serde(default)]
    pub page: Option<u32>,
    /// 每页大小；省略则返回不分页列表（所有匹配行）。
    #[serde(default)]
    pub limit: Option<u32>,
}

/// 资产列表端点的分页响应。
///
/// 包含匹配的资产行和用于分页元数据的总数。
#[derive(Debug, Serialize)]
pub struct ListAssetsResponse {
    /// 当前页的资产行。
    pub items: Vec<AssetRow>,
    /// 匹配查询的资产总数（跨所有页）。
    pub total: i64,
}

/// 遗留 `POST /api/cornerScape/getAllAssets`：顶级项目资产。
///
/// 扩展资产项，包含元数据 JSON 和历史图片，用于角景视图。
#[derive(Debug, Serialize)]
pub struct CornerScapeAssetItem {
    /// 内部 UUID 主键。
    pub id: Uuid,
    /// 向客户端暴露的稳定整数 ID（JSON **`numeric_id`**）。
    #[serde(rename = "numeric_id")]
    pub numeric_id: i32,
    /// 资产显示名称。
    pub name: String,
    /// 资产分类：role、tool 或 scene。
    pub asset_type: String,
    /// 可选的描述文本。
    pub description: Option<String>,
    /// 创建时间戳（毫秒）。
    pub create_time_ms: Option<i64>,
    /// 灵活的元数据 JSON 对象（提示词、备注、遗留 ID 等）。
    pub metadata: Value,
    /// 历史图片记录，以 JSON 值表示。
    pub history_images: Vec<Value>,
}

/// 角景资产列表的响应包装器。
#[derive(Debug, Serialize)]
pub struct CornerScapeResponse {
    /// 角景资产项列表。
    pub items: Vec<CornerScapeAssetItem>,
}

/// 角景资产查询端点的请求体。
///
/// 允许按资产类型（role、scene、tool）过滤。
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CornerScapeBody {
    /// 可选的资产类型过滤列表。
    #[serde(default)]
    pub types: Option<Vec<String>>,
}

/// 角景查询的数据库行类型。
///
/// 镜像 `AssetRow`，使用 SQLx 包装的 JSON 列存储元数据和历史记录。
#[derive(Debug, FromRow)]
pub(super) struct CornerScapeDbRow {
    /// 内部 UUID 主键。
    pub id: Uuid,
    /// 遗留整数 ID。
    #[sqlx(rename = "legacy_id")]
    pub numeric_id: i32,
    /// 显示名称。
    pub name: String,
    /// 资产分类。
    pub asset_type: String,
    /// 可选的描述。
    pub description: Option<String>,
    /// 创建时间戳（毫秒）。
    pub create_time_ms: Option<i64>,
    /// 元数据，SQLx JSON 格式。
    pub metadata: SqlxJson<Value>,
    /// 历史图片，SQLx JSON 数组格式。
    pub history_images: SqlxJson<Value>,
}

/// 创建新资产的请求体。
///
/// 需要名称和类型；描述是可选的。
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CreateAssetBody {
    /// 新资产的显示名称。
    pub name: String,
    /// 资产类型：role、tool 或 scene。
    #[serde(rename = "type")]
    pub asset_type: String,
    /// 可选的描述或提示词文本。
    #[serde(default)]
    pub description: Option<String>,
}

/// JSON Patch 风格的更新现有资产请求体。
///
/// 所有字段都是可选的 JSON 值，支持 `null` 删除和字段省略。
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct PatchAssetBody {
    /// 新名称，`null` 表示清除，或省略以保持不变。
    #[serde(default)]
    pub name: Option<Value>,
    /// 新描述，`null` 表示清除，或省略。
    #[serde(default)]
    pub description: Option<Value>,
    /// 新资产类型，`null` 表示清除，或省略。
    #[serde(default)]
    pub asset_type: Option<Value>,
    /// 封面图片稳定整数 ID，`null` 表示清除，或省略（JSON **`cover_numeric_image_id`**）。
    #[serde(default, rename = "cover_numeric_image_id")]
    pub cover_numeric_image_id: Option<Value>,
}

/// 单个 `app_asset_image` 行。
///
/// 表示与资产关联的图片（生成或上传）。
#[derive(Debug, FromRow, Serialize)]
pub struct AssetImageRow {
    /// 内部 UUID 主键。
    pub id: Uuid,
    /// 外键，指向 `app_asset.id`。
    pub asset_id: Uuid,
    /// 资产图片库中的显示顺序。
    pub sort_index: i32,
    /// 图片文件的 URL 或本地路径。
    pub file_path: Option<String>,
    /// 生成状态：如 pending、completed、failed。
    pub state: Option<String>,
    /// 图片的稳定整数 ID（`legacy_image_id` 列；JSON **`numeric_image_id`**）。
    #[serde(rename = "numeric_image_id")]
    #[sqlx(rename = "legacy_image_id")]
    pub numeric_image_id: Option<i32>,
}

/// 带选择标志的资产图片项。
///
/// 在列表响应中使用，指示此图片当前是否被选中。
#[derive(Debug, Serialize)]
pub struct AssetImageListItem {
    /// 底层图片行数据。
    #[serde(flatten)]
    pub row: AssetImageRow,
    /// 此图片当前是否被选中。
    pub selected: bool,
}

/// 列出资产图片的响应。
///
/// 包含封面图片 ID 和完整图片列表。
#[derive(Debug, Serialize)]
pub struct ListAssetImagesResponse {
    /// 当前选中的封面图片稳定整数 ID（JSON **`cover_numeric_image_id`**）。
    #[serde(rename = "cover_numeric_image_id")]
    pub cover_numeric_image_id: Option<i32>,
    /// 带选择标志的图片列表。
    pub items: Vec<AssetImageListItem>,
}

/// 创建新资产图片的请求体。
///
/// 所有字段都是可选的；默认值由数据库应用。
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CreateAssetImageBody {
    /// 图片的 URL 或本地文件路径。
    #[serde(default)]
    pub file_path: Option<String>,
    /// 生成状态：pending、completed、failed。
    #[serde(default)]
    pub state: Option<String>,
    /// 图库中的显示顺序（越小越靠前）。
    #[serde(default)]
    pub sort_index: Option<i32>,
}

/// JSON Patch 风格的更新资产图片请求体。
///
/// 支持部分更新，`null` 表示清除字段。
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct PatchAssetImageBody {
    /// 新文件路径，`null` 表示清除，或省略。
    #[serde(default)]
    pub file_path: Option<Value>,
    /// 新状态，`null` 表示清除，或省略。
    #[serde(default)]
    pub state: Option<Value>,
    /// 新排序索引，`null` 表示清除，或省略。
    #[serde(default)]
    pub sort_index: Option<Value>,
}

/// 获取图片文件源信息的轻量级行类型。
#[derive(Debug, FromRow)]
pub(super) struct AssetImageFileSource {
    /// 图片文件的 URL 或本地路径。
    pub file_path: Option<String>,
    /// 来自 `app_asset` 的元数据 JSON。
    pub metadata: SqlxJson<Value>,
}

// ── Legacy request/response types ───────────────────────────────────────────

/// 遗留 get-image 端点的请求体。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyGetImageBody {
    /// 要获取图片的遗留资产 ID。
    pub assets_id: i32,
}

/// 遗留 upload-clip 端点的响应。
#[derive(Debug, Serialize)]
pub(super) struct LegacyUploadClipResponse {
    /// 人类可读的状态消息。
    pub message: String,
}

/// 遗留 update-assets 端点的请求体。
///
/// 通过遗留 ID 更新现有资产的元数据。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct LegacyUpdateAssetsBody {
    /// 要更新的遗留资产 ID。
    pub id: i32,
    /// 新的显示名称。
    pub name: String,
    /// 新的描述文本。
    pub describe: String,
    /// 可选的备注更新。
    #[serde(default)]
    pub remark: Option<String>,
    /// 可选的提示词更新。
    #[serde(default)]
    pub prompt: Option<String>,
}

/// 遗留 delete-assets 端点的请求体。
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyDeleteAssetsBody {
    /// 要删除的遗留资产 ID。
    pub id: i32,
}

/// 遗留 batch-delete 端点的请求体。
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyBatchDeleteAssetsBody {
    /// 要删除的遗留资产 ID 列表。
    pub id: Vec<i32>,
}

/// 遗留 delete-image 端点的请求体。
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyDelImageBody {
    /// 要删除的遗留图片 ID。
    pub id: i32,
}

/// 遗留资产变更的通用成功响应。
#[derive(Debug, Serialize)]
pub(super) struct LegacyAssetMutationResponse {
    /// 成功消息字符串。
    pub message: &'static str,
}

/// 遗留 polling-image-assets 端点的请求体。
///
/// 通过 ID 轮询多个图片资产的状态。
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyPollingImageAssetsBody {
    /// 要轮询的资产 ID 列表。
    pub ids: Vec<i32>,
}

/// polling-image-assets 响应中的单项。
#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyPollingImageAssetsItem {
    /// 遗留资产 ID。
    pub id: i32,
    /// 当前生成状态。
    pub state: Option<String>,
    /// 图片文件的 URL 或路径。
    pub file_path: Option<String>,
}

/// 遗留 polling-prompt-assets 端点的请求体。
///
/// 轮询多个资产的提示词优化状态。
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct LegacyPollingPromptAssetsBody {
    /// 要轮询提示词状态的资产 ID 列表。
    pub ids: Vec<i32>,
}

/// 素材数据响应中的资产项。
#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyMaterialAssetItem {
    /// 遗留资产 ID。
    pub id: i32,
    /// 显示名称。
    pub name: String,
    /// 资产文件的 URL 或路径。
    pub file_path: String,
    /// 资产类型分类。
    #[serde(rename = "type")]
    pub asset_type: String,
}

/// 素材数据响应中的视频项。
#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyMaterialVideoItem {
    /// 视频遗留 ID。
    pub id: i32,
    /// 视频文件 URL 或路径。
    pub file_path: String,
    /// 多轨道视频的轨道 ID（可选）。
    pub video_track_id: Option<i32>,
}

/// 遗留 get-material-data 端点的响应。
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetMaterialDataResponse {
    /// 素材资源列表。
    pub data: Vec<LegacyMaterialAssetItem>,
    /// 视频素材列表。
    pub video: Vec<LegacyMaterialVideoItem>,
}

/// batch-generation-data 响应中的资产项。
#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyBatchGenerationAssetItem {
    /// 遗留资产 ID。
    pub id: i32,
    /// 显示名称。
    pub name: String,
    /// 资产类型分类。
    #[serde(rename = "type")]
    pub asset_type: String,
    /// 可选的描述或提示词。
    pub description: Option<String>,
    /// 创建时间戳（毫秒）。
    pub create_time_ms: Option<i64>,
}

/// 遗留 batch-generation-data 端点的响应。
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyBatchGenerationDataResponse {
    /// 匹配的资产列表。
    pub data: Vec<LegacyBatchGenerationAssetItem>,
    /// 分页总数量。
    pub total: i64,
}

/// polling-prompt-assets 响应中的单项。
#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyPollingPromptAssetsItem {
    /// 遗留资产 ID。
    pub id: i32,
    /// 显示名称。
    pub name: String,
    /// 资产类型分类。
    #[serde(rename = "type")]
    pub asset_type: String,
    /// 当前提示词优化状态：如 pending、completed。
    pub prompt_state: String,
}

/// get-image 响应中的临时/生成资产项。
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetImageTempAssetItem {
    /// 可选的遗留图片 ID。
    pub id: Option<i32>,
    /// 此图片实例的 UUID。
    pub image_uuid: Uuid,
    /// 图片文件 URL 或路径。
    pub file_path: String,
    /// 父资产遗留 ID。
    pub assets_id: i32,
    /// 资产类型分类。
    #[serde(rename = "type")]
    pub asset_type: String,
    /// 生成状态。
    pub state: Option<String>,
    /// 是否被选为封面图。
    pub selected: bool,
}

/// 遗留 get-image 端点的响应。
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetImageResponse {
    /// 遗留资产 ID。
    pub id: i32,
    /// 当前选中的封面图片 ID。
    pub image_id: Option<i32>,
    /// 该资产的生成/临时图片列表。
    pub temp_assets: Vec<LegacyGetImageTempAssetItem>,
}

/// 遗留 get-image 查询的数据库行类型。
#[derive(Debug, FromRow)]
pub(super) struct LegacyGetImageAssetRow {
    /// 内部 UUID。
    pub id: Uuid,
    /// 遗留整数 ID。
    #[sqlx(rename = "legacy_id")]
    pub numeric_id: i32,
    /// 资产类型分类。
    pub asset_type: String,
    /// 元数据 JSON。
    pub metadata: SqlxJson<Value>,
}

/// **`POST …/projects/{project_id}/assets/workbench/nested`** — 同 get-assets-api，项目 UUID 在路径。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct WorkbenchNestedAssetsBody {
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub page: Option<i32>,
    #[serde(default)]
    pub limit: Option<i32>,
}

/// **`POST …/projects/{project_id}/assets/workbench/upload-clip`**。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct WorkbenchUploadClipBody {
    pub base64_data: String,
    #[serde(default, alias = "type")]
    pub asset_type: Option<String>,
    pub name: String,
}

/// **`POST …/projects/{project_id}/assets/workbench/material-data`** — 空对象体。
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct WorkbenchEmptyBody {}

/// **`POST …/projects/{project_id}/assets/workbench/batch-generation-data`**。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct WorkbenchBatchGenerationDataBody {
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub name: Option<String>,
    pub page: i32,
    pub limit: i32,
}

/// **`POST …/projects/{project_id}/assets/workbench/add-assets`**。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct WorkbenchAddAssetsBody {
    pub name: String,
    pub describe: String,
    #[serde(rename = "type")]
    pub asset_type: String,
    #[serde(default)]
    pub remark: Option<String>,
    #[serde(default)]
    pub prompt: Option<String>,
}

/// **`POST …/projects/{project_id}/assets/workbench/save-assets`**。
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct WorkbenchSaveAssetsBody {
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

/// get-assets-api 响应中的子/附属资产项。
///
/// 表示附加到父资产的生成图片或子资产。
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetAssetsApiChildItem {
    /// 此子项的遗留 ID。
    pub id: i32,
    /// 遗留项目 ID。
    pub project_id: i32,
    /// 资产类型分类。
    #[serde(rename = "type")]
    pub asset_type: String,
    /// 显示名称。
    pub name: String,
    /// 父资产遗留 ID。
    pub assets_id: Option<i32>,
    /// 选中的图片 ID。
    pub image_id: Option<i32>,
    /// 文件 URL 或路径。
    pub file_path: Option<String>,
    /// 生成状态。
    pub state: Option<String>,
    /// 生成失败的错误信息。
    pub error_reason: Option<String>,
    /// 源 URL（通常与 file_path 相同）。
    pub src: Option<String>,
}

/// get-assets-api 响应中的父级/顶级资产项。
///
/// 包含主资产数据及嵌套的子资产（生成的图片）。
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetAssetsApiParentItem {
    /// 遗留资产 ID。
    pub id: i32,
    /// 遗留项目 ID。
    pub project_id: i32,
    /// 资产类型分类。
    #[serde(rename = "type")]
    pub asset_type: String,
    /// 显示名称。
    pub name: String,
    /// 父级引用（顶级资产通常为 None）。
    pub assets_id: Option<i32>,
    /// 当前选中的图片 ID。
    pub image_id: Option<i32>,
    /// 选中图片的 URL 或路径。
    pub file_path: Option<String>,
    /// 选中图片的生成状态。
    pub state: Option<String>,
    /// 生成失败的错误原因。
    pub error_reason: Option<String>,
    /// 选中图片的源 URL。
    pub src: Option<String>,
    /// 嵌套的子资产列表（生成的图片）。
    pub son_assets: Vec<LegacyGetAssetsApiChildItem>,
}

/// 遗留 get-assets-api 端点的响应。
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyGetAssetsApiResponse {
    /// 带嵌套子项的父级资产列表。
    pub data: Vec<LegacyGetAssetsApiParentItem>,
    /// 分页总数量。
    pub total: i64,
}

/// get-assets-api 查询的扁平数据库行类型。
///
/// 同时表示父级和子级资产；逻辑根据数据区分。
#[derive(Debug, FromRow)]
pub(super) struct LegacyGetAssetsApiDbRow {
    /// 遗留 ID。
    pub id: i32,
    /// 遗留项目 ID（子项为 null）。
    pub project_id: Option<i32>,
    /// 资产类型分类。
    pub asset_type: String,
    /// 显示名称。
    pub name: String,
    /// 子项的父资产 ID。
    pub assets_id: Option<i32>,
    /// 选中的图片 ID。
    pub image_id: Option<i32>,
    /// 文件路径或 URL。
    pub file_path: Option<String>,
    /// 生成状态。
    pub state: Option<String>,
    /// 失败时的错误原因。
    pub error_reason: Option<String>,
}

// ── 内部辅助类型 ─────────────────────────────────────────────────────────

/// 用于解析资产所有权和元数据的内部行类型。
///
/// 用于验证用户所有权和提取变更时的元数据。
#[derive(Debug, FromRow)]
pub(crate) struct LegacyOwnedAssetMetaRow {
    /// 内部 UUID。
    pub id: Uuid,
    /// 元数据 JSON。
    pub metadata: SqlxJson<Value>,
}

/// 应用 PATCH 更新前获取的当前资产状态。
///
/// 用于乐观锁和合并元数据变更。
#[derive(Debug, FromRow)]
pub(super) struct AssetPatchCurrent {
    /// 内部 UUID。
    pub id: Uuid,
    /// 当前名称。
    pub name: String,
    /// 当前资产类型。
    pub asset_type: String,
    /// 当前描述。
    pub description: Option<String>,
    /// 当前元数据 JSON。
    pub metadata: SqlxJson<Value>,
}
