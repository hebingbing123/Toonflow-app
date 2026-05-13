use chrono::{TimeZone, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

/// HTTP 响应里标明聚合/变更口径：**`user`** = 按 `owner_user_id` 行级隔离（与 `app_agent_memory` 一致）。
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub(crate) enum AgentMemoryResponseScope {
    User,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct QueryMemoryBody {
    /// Preferred: **`app_project.id`** (UUID), same as `/api/v1/projects/{project_id}`.
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    /// Legacy: **`app_project.numeric_id`** (Electron / SQLite-era).
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    pub(crate) agent_type: String,
    #[serde(default)]
    pub(crate) episodes_id: Option<i32>,
    /// `message` | `summary` | `all` — default `message` to preserve Electron-era query behavior.
    #[serde(default = "default_query_memory_type")]
    pub(crate) memory_type: String,
    /// 可选过滤字段：`style_bible` | `stage_summary` | `delta_memory` | `message`
    #[serde(default)]
    pub(crate) memory_tier: Option<String>,
    /// 可选精确作用域过滤；若命中则优先返回 exact scope 结果
    #[serde(default)]
    pub(crate) scope_signature: Option<serde_json::Value>,
}

fn default_query_memory_type() -> String {
    "message".to_string()
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ClearMemoryBody {
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
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
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    pub(crate) agent_type: String,
    #[serde(default)]
    pub(crate) episodes_id: Option<i32>,
    #[serde(default)]
    pub(crate) automation_mode: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AppendMemoryBody {
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
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
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub(crate) scope: &'static str,
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
#[serde(rename_all = "camelCase")]
pub(crate) struct AppendMemoryResponse {
    pub(crate) scope: AgentMemoryResponseScope,
    pub(crate) id: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ClearMemoryResponse {
    pub(crate) scope: AgentMemoryResponseScope,
    pub(crate) ok: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct OptimizeMemoryResponse {
    pub(crate) scope: AgentMemoryResponseScope,
    pub(crate) automation_mode: String,
    pub(crate) removed_rows: usize,
    pub(crate) removed_chars: usize,
    pub(crate) removed_visual_rows: usize,
    pub(crate) removed_duplicate_rows: usize,
    pub(crate) removed_low_value_rows: usize,
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
        scope: "user",
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
