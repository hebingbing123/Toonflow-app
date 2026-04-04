use uuid::Uuid;

use super::tools::ToolRegistry;

/// Future: tool allowlists, quotas, tenant isolation. MVP: authenticated users only.
pub fn ws_channel_allowed(_user: Uuid, _channel: &str) -> bool {
    true
}

/// True when `tool_name` is listed in the static Harness tool catalog.
pub fn tool_invocation_allowed(_user: Uuid, tool_name: &str) -> bool {
    ToolRegistry::catalog().iter().any(|t| t.name == tool_name)
}
