//! JSON **`payload`** shapes for WebSocket envelopes (`schema_version` **1**): Harness tools, agent loop, and session attach.

use serde::Deserialize;
use serde_json::Value;

// --- Session auth (`session.auth`) ---

#[derive(Debug, Deserialize)]
pub struct SessionAuthPayload {
    pub access_token: String,
}

// --- Agent channel attach (`agent.script.attach`, `agent.production.attach`, `agent.context.update`) ---

#[derive(Debug, Deserialize)]
pub struct AttachScriptPayload {
    pub isolation_key: String,
    pub project_id: i64,
}

#[derive(Debug, Deserialize)]
pub struct AttachProductionPayload {
    pub isolation_key: String,
    pub project_id: i64,
    pub script_id: i64,
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
}
