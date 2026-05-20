//! 编译时嵌入的 `models_catalog.json` 与内部行结构。

use std::sync::LazyLock;

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub(in crate::vendor::catalog) struct CatalogFile {
    pub(in crate::vendor::catalog) vendors: Vec<VendorDef>,
}

#[derive(Debug, Deserialize)]
pub(in crate::vendor::catalog) struct VendorDef {
    pub(in crate::vendor::catalog) id: i32,
    pub(in crate::vendor::catalog) name: String,
    /// OpenAI-compatible API base (e.g. Ollama `http://127.0.0.1:11434/v1`).
    #[serde(default)]
    pub(in crate::vendor::catalog) default_base_url: Option<String>,
    /// When true, chat works without a stored API key (local servers).
    #[serde(default)]
    pub(in crate::vendor::catalog) api_key_optional: bool,
    /// `openai` | `anthropic` | `gemini_native` | `volcengine_ark` | `azure_openai`
    #[serde(default)]
    pub(in crate::vendor::catalog) protocol: Option<String>,
    /// For video-only vendors: `runway` | `pika` | `kling` | `doubao` | `hunyuan` | …
    #[serde(default)]
    pub(in crate::vendor::catalog) video_provider: Option<String>,
    pub(in crate::vendor::catalog) models: Vec<ModelDef>,
}

#[derive(Debug, Deserialize, Clone)]
pub(in crate::vendor::catalog) struct ModelDef {
    pub(in crate::vendor::catalog) name: String,
    pub(in crate::vendor::catalog) model_name: String,
    #[serde(rename = "type")]
    pub(in crate::vendor::catalog) kind: String,
}

pub(in crate::vendor::catalog) static CATALOG: LazyLock<CatalogFile> = LazyLock::new(|| {
    serde_json::from_str(include_str!("../../../data/models_catalog.json"))
        .expect("models_catalog.json must be valid JSON")
});
