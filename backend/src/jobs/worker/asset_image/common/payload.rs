//! 任务 payload 小工具与生成上下文。

use std::path::Path;

use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::common::JobRunError;
use crate::llm::LlmConfig;

pub(crate) fn combine_image_prompt(name: &str, body: &str) -> String {
    let n = name.trim();
    let b = body.trim();
    match (n.is_empty(), b.is_empty()) {
        (true, true) => String::new(),
        (true, false) => b.to_string(),
        (false, true) => n.to_string(),
        (false, false) => format!("{n}\n{b}"),
    }
}

pub(crate) fn payload_json_i32(value: &Value, field: &'static str) -> Result<i32, JobRunError> {
    value
        .get(field)
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| JobRunError::Failed(format!("payload missing or invalid {field}")))
}

pub(crate) struct AssetImageGenCtx<'a> {
    pub(crate) cfg: &'a LlmConfig,
    pub(crate) http_client: &'a reqwest::Client,
    pub(crate) pool: &'a PgPool,
    pub(crate) job_id: Uuid,
    pub(crate) owner: Uuid,
    pub(crate) request_model: &'a str,
    pub(crate) image_model: &'a str,
    pub(crate) size: &'a str,
    /// When set, worker downloads the provider URL and writes `{dir}/{owner}/{id}.png`.
    pub(crate) local_asset_image_dir: Option<&'a Path>,
}
