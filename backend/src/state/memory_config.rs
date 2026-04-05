//! Legacy SQLite **`o_setting`** keys for memory / RAG UI (**camelCase** JSON).

use serde::{Deserialize, Serialize};

/// Same shape as legacy **`getMemory`** **`data`** object.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct MemoryConfig {
    pub messages_per_summary: i64,
    pub short_term_limit: i64,
    pub summary_max_length: i64,
    pub summary_limit: i64,
    pub rag_limit: i64,
    pub deep_retrieve_summary_limit: i64,
    pub model_onnx_file: Vec<String>,
    pub model_dtype: String,
}

impl MemoryConfig {
    pub fn default_legacy() -> Self {
        Self {
            messages_per_summary: 10,
            short_term_limit: 5,
            summary_max_length: 500,
            summary_limit: 10,
            rag_limit: 3,
            deep_retrieve_summary_limit: 5,
            model_onnx_file: vec![
                "all-MiniLM-L6-v2".into(),
                "onnx".into(),
                "model_fp16.onnx".into(),
            ],
            model_dtype: "fp16".into(),
        }
    }
}
