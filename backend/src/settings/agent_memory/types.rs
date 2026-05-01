use chrono::{TimeZone, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct QueryMemoryBody {
    pub(crate) project_id: i32,
    pub(crate) agent_type: String,
    #[serde(default)]
    pub(crate) episodes_id: Option<i32>,
    /// `message` | `summary` | `all` — default `message` to preserve Electron-era query behavior.
    #[serde(default = "default_query_memory_type")]
    pub(crate) memory_type: String,
    /// 可选过滤字段：`style_bible` | `stage_summary` | `delta_memory` | `message`
    #[serde(default)]
    pub(crate) memory_tier: Option<String>,
}

fn default_query_memory_type() -> String {
    "message".to_string()
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ClearMemoryBody {
    pub(crate) project_id: i32,
    pub(crate) agent_type: String,
    #[serde(default)]
    pub(crate) episodes_id: Option<i32>,
    /// `all` | `message` | `summary` — same semantics as Electron-era clearMemory (`type`).
    #[serde(default = "default_clear_kind", alias = "type")]
    pub(crate) clear_type: String,
}

fn default_clear_kind() -> String {
    "all".to_string()
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct OptimizeMemoryBody {
    pub(crate) project_id: i32,
    pub(crate) agent_type: String,
    #[serde(default)]
    pub(crate) episodes_id: Option<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AppendMemoryBody {
    pub(crate) project_id: i32,
    pub(crate) agent_type: String,
    #[serde(default)]
    pub(crate) episodes_id: Option<i32>,
    #[serde(default = "default_append_memory_type")]
    pub(crate) memory_type: String,
    #[serde(default = "default_role")]
    pub(crate) role: String,
    pub(crate) content: String,
    #[serde(default)]
    pub(crate) name: Option<String>,
    #[serde(default)]
    pub(crate) create_time: Option<i64>,
    /// 记忆分层：`style_bible` | `stage_summary` | `delta_memory` | `message`（默认 `message`）
    #[serde(default)]
    pub(crate) memory_tier: Option<String>,
    /// 范围签名，用于标记记忆的作用范围（如 storyboardIds、assetIds 等）
    #[serde(default)]
    pub(crate) scope_signature: Option<serde_json::Value>,
}

fn default_role() -> String {
    "user".to_string()
}

fn default_append_memory_type() -> String {
    "message".to_string()
}

#[derive(Debug, sqlx::FromRow)]
pub(crate) struct MessageRow {
    pub(crate) id: Uuid,
    pub(crate) role: Option<String>,
    pub(crate) name: Option<String>,
    pub(crate) memory_tier: Option<String>,
    pub(crate) content: String,
    pub(crate) create_time_ms: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ContentBlock {
    #[serde(rename = "type")]
    pub(crate) block_type: &'static str,
    pub(crate) status: &'static str,
    pub(crate) data: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MemoryHistoryItem {
    pub(crate) id: String,
    pub(crate) role: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) name: Option<String>,
    pub(crate) memory_tier: String,
    pub(crate) status: &'static str,
    pub(crate) datetime: String,
    pub(crate) content: Vec<ContentBlock>,
    pub(crate) create_time: i64,
}

#[derive(Serialize)]
pub(crate) struct AppendMemoryResponse {
    pub(crate) id: String,
}

#[derive(Serialize)]
pub(crate) struct ClearMemoryResponse {
    pub(crate) ok: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct OptimizeMemoryResponse {
    pub(crate) removed_rows: usize,
    pub(crate) removed_chars: usize,
    pub(crate) removed_visual_rows: usize,
    pub(crate) removed_duplicate_rows: usize,
    pub(crate) refreshed_script_summary: bool,
    pub(crate) refreshed_project_summary: bool,
}

pub(crate) fn normalize_role(role: Option<String>) -> String {
    match role {
        Some(r) if r.starts_with("assistant") => "assistant".to_string(),
        _ => "user".to_string(),
    }
}

pub(crate) fn to_memory_history_item(row: MessageRow) -> MemoryHistoryItem {
    let dt = Utc
        .timestamp_millis_opt(row.create_time_ms)
        .single()
        .unwrap_or_else(Utc::now);
    let memory_tier = row.memory_tier.unwrap_or_else(|| "message".to_string());
    MemoryHistoryItem {
        id: row.id.to_string(),
        role: normalize_role(row.role),
        name: row.name,
        memory_tier,
        status: "complete",
        datetime: dt.to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
        content: vec![ContentBlock {
            block_type: "markdown",
            status: "complete",
            data: row.content,
        }],
        create_time: row.create_time_ms,
    }
}
