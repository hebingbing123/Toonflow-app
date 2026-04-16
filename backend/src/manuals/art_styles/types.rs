use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use utoipa::OpenApi;
use utoipa::ToSchema;
use uuid::Uuid;

pub(super) const ADV_LOCK_ART_STYLE_NUMERIC: i64 = 884_422_008;
pub(super) const MAX_ART_STYLE_LIST: i64 = 500;
pub(super) const MAX_EXTRACT_IMAGES: usize = 16;
/// Per-image cap for `data:` / URL strings (Electron-era extractStylePrompt had no limit).
pub(super) const MAX_IMAGE_ENTRY_BYTES: usize = 20 * 1024 * 1024;
pub(super) const MAX_ART_STYLE_COVER_INPUT_CHARS: usize = 20 * 1024 * 1024;
pub(super) const MAX_ART_STYLE_COVER_BYTES: usize = 15 * 1024 * 1024;

/// System prompt aligned with Electron-era `src/routes/artStyle/extractStylePrompt.ts`.
pub(super) const EXTRACT_STYLE_SYSTEM_PROMPT: &str = r#"请根据以下图片数据，提取出图片的画风提示词，用于生成图片时指定风格，要求简洁且具有艺术性,只需要画风提示词，不需要其他内容："比如：`(画风：2D动漫风格,2d animation style)`,`(画风：照片级真人超写实,photorealistic, lifelike, ultra detailed)`，`(画风：3D国创,Chinese 3D animation style)`等,如果图片风格无法描述，可以返回`无法描述`,多张图片时，只输出一个综合的画风提示词，要求包含所有图片的共同风格特征，输出格式必须严格按照示例中的格式，必须包含`画风`二字，且必须使用括号括起来，括号内必须包含中文和英文的画风描述，并用逗号分隔，英文部分需要翻译成地道的英文提示词"#;

#[derive(Debug, FromRow, Serialize, ToSchema)]
#[schema(
    title = "ArtStyleRow",
    description = "One `app_art_style` row (Electron-era `o_artStyle` subset)."
)]
pub struct ArtStyleRow {
    pub id: Uuid,
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: String,
    #[schema(nullable = true)]
    pub file_url: Option<String>,
    #[schema(nullable = true)]
    pub label: Option<String>,
    #[schema(nullable = true)]
    pub prompt: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ListArtStylesResponse {
    pub items: Vec<ArtStyleRow>,
    pub total: i64,
}

#[derive(Debug, Deserialize, Default, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct CreateArtStyleBody {
    pub name: String,
    #[serde(default)]
    #[schema(nullable = true)]
    pub file_url: Option<String>,
    #[serde(default)]
    #[schema(nullable = true)]
    pub label: Option<String>,
    #[serde(default)]
    #[schema(nullable = true)]
    pub prompt: Option<String>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct ExtractArtStylePromptBody {
    #[schema(min_items = 1, max_items = 16)]
    pub images: Vec<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ExtractArtStylePromptResponse {
    pub text: String,
}

#[derive(Debug, Deserialize, Default, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct PatchArtStyleBody {
    #[serde(default)]
    #[schema(nullable = true, value_type = Object)]
    pub name: Option<Value>,
    #[serde(default)]
    #[schema(nullable = true, value_type = Object)]
    pub file_url: Option<Value>,
    #[serde(default)]
    #[schema(nullable = true, value_type = Object)]
    pub label: Option<Value>,
    #[serde(default)]
    #[schema(nullable = true, value_type = Object)]
    pub prompt: Option<Value>,
}

/// OpenAPI component schemas for art-style REST.
#[derive(OpenApi)]
#[openapi(components(schemas(
    ArtStyleRow,
    ListArtStylesResponse,
    CreateArtStyleBody,
    ExtractArtStylePromptBody,
    ExtractArtStylePromptResponse,
    PatchArtStyleBody,
)))]
pub struct ArtStyleSchemasOpenApi;
