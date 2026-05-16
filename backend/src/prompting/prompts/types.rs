//! 提示词模板 HTTP / DB 类型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, FromRow)]
pub(super) struct UserPromptRow {
    #[sqlx(rename = "numeric_id")]
    pub(super) numeric_id: i32,
    pub(super) name: Option<String>,
    pub(super) kind: String,
    pub(super) body: String,
}

/// JSON shape aligned with Electron-era **`getPrompt`** rows (`id`, `name`, `type`, `data`).
#[derive(Debug, Serialize)]
pub struct PromptTemplateJson {
    pub id: i32,
    pub name: String,
    #[serde(rename = "type")]
    pub prompt_type: String,
    pub data: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PatchPromptBody {
    pub data: String,
}
