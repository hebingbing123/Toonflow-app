//! JSON payload shapes for WebSocket messages typed under the Harness surface (`harness.tool.invoke`, `harness.agent.run`).

use serde::Deserialize;
use serde_json::Value;

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
