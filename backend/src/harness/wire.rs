//! WebSocket 信封的 JSON payload 结构（`schema_version` 1）。
//!
//! 包含 Harness 工具、代理循环和会话附加的数据结构。

use serde::Deserialize;
use serde_json::Value;
use uuid::Uuid;

// --- Session auth (`session.auth`) ---

#[derive(Debug, Deserialize)]
pub struct SessionAuthPayload {
    pub access_token: String,
}

// --- Agent channel attach (`agent.script.attach`, `agent.production.attach`, `agent.context.update`) ---

#[derive(Debug, Deserialize)]
pub struct AttachScriptPayload {
    pub isolation_key: String,
    /// Preferred: **`app_project.id`** (camelCase **`projectUuid`** on the wire).
    #[serde(rename = "projectUuid")]
    #[serde(default)]
    pub project_uuid: Option<Uuid>,
    /// Optional claim; when set, must match **`app_project.workspace_id`** after DB resolve.
    #[serde(rename = "workspaceUuid")]
    #[serde(default)]
    pub workspace_uuid: Option<Uuid>,
    /// Legacy: **`app_project.numeric_id`**.
    #[serde(default)]
    pub project_id: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct AttachProductionPayload {
    pub isolation_key: String,
    #[serde(rename = "projectUuid")]
    #[serde(default)]
    pub project_uuid: Option<Uuid>,
    #[serde(rename = "workspaceUuid")]
    #[serde(default)]
    pub workspace_uuid: Option<Uuid>,
    #[serde(default)]
    pub project_id: Option<i64>,
    #[serde(rename = "scriptUuid")]
    #[serde(default)]
    pub script_uuid: Option<Uuid>,
    #[serde(default)]
    pub script_id: Option<i64>,
}

// --- Streaming chat (`agent.chat.send`) ---

#[derive(Debug, Deserialize)]
pub struct ChatSendPayload {
    pub content: String,
}

// --- Harness tool / agent run ---

#[derive(Debug, Deserialize)]
pub struct HarnessToolInvokePayload {
    pub name: String,
    #[serde(default)]
    pub arguments: Option<Value>,
}

fn default_max_tool_rounds() -> usize {
    8
}

#[derive(Debug, Deserialize)]
pub struct HarnessAgentRunPayload {
    pub content: String,
    #[serde(default = "default_max_tool_rounds")]
    pub max_tool_rounds: usize,
    /// When **`true`**, request WP‑E streaming fusion (tool calls interleaved with streamed assistant text).
    /// Until **`HARNESS_AGENT_STREAMING_TOOLS`** enables the server path, omit this field or use **`false`**.
    #[serde(default)]
    pub stream: Option<bool>,
    /// Optional catalog composite id; overrides project step routing when set.
    #[serde(default)]
    pub model_id: Option<String>,
}

#[cfg(test)]
mod attach_payload_tests {
    use super::*;

    #[test]
    fn attach_script_deserializes_legacy_numeric_only() {
        let v = serde_json::json!({
            "isolation_key": "k",
            "project_id": 7_i64,
        });
        let p: AttachScriptPayload = serde_json::from_value(v).unwrap();
        assert_eq!(p.isolation_key, "k");
        assert!(p.project_uuid.is_none());
        assert_eq!(p.project_id, Some(7));
    }

    #[test]
    fn attach_script_deserializes_uuid_and_numeric_dual_write() {
        let u = Uuid::nil();
        let v = serde_json::json!({
            "isolation_key": "k",
            "projectUuid": u,
            "project_id": 3_i64,
        });
        let p: AttachScriptPayload = serde_json::from_value(v).unwrap();
        assert_eq!(p.project_uuid, Some(u));
        assert_eq!(p.project_id, Some(3));
    }

    #[test]
    fn harness_agent_run_deserializes_optional_stream() {
        let v = serde_json::json!({
            "content": "hello",
            "max_tool_rounds": 3,
            "stream": true,
        });
        let p: HarnessAgentRunPayload = serde_json::from_value(v).unwrap();
        assert_eq!(p.stream, Some(true));
    }

    #[test]
    fn attach_script_deserializes_workspace_uuid() {
        let u = Uuid::nil();
        let w = Uuid::from_u128(0xffee_ddcc_bbaa_9988_7766_5544_3322);
        let v = serde_json::json!({
            "isolation_key": "k",
            "projectUuid": u,
            "workspaceUuid": w,
        });
        let p: AttachScriptPayload = serde_json::from_value(v).unwrap();
        assert_eq!(p.workspace_uuid, Some(w));
    }
}
