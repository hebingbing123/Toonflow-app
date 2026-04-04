use super::HarnessContext;
use uuid::Uuid;

pub fn ws_frame(ctx: &HarnessContext, msg_type: &str) {
    tracing::debug!(user_id = %ctx.user_id, %msg_type, "harness.ws");
}

pub fn agent_llm_turn_requested(user_id: Uuid, content_len: usize) {
    tracing::info!(%user_id, content_len, "harness.agent_llm_turn");
}

pub fn harness_tool_invoke(ctx: &HarnessContext, tool_name: &str) {
    tracing::info!(user_id = %ctx.user_id, %tool_name, "harness.tool.invoke");
}

pub fn harness_tools_catalog_http(user_id: Uuid) {
    tracing::debug!(%user_id, "harness.http.tools_catalog");
}

/// REST **`/api/v1/agents/memory/*`** (parity with legacy agent memory).
pub fn memory_http(user_id: Uuid, legacy_project_id: i32, op: &'static str) {
    tracing::debug!(%user_id, legacy_project_id, %op, "harness.memory.http");
}

/// Worker claimed or finished a row in **`app_generation_job`** (best-effort tracing).
pub fn generation_job(user_id: Uuid, job_id: Uuid, phase: &'static str) {
    tracing::debug!(%user_id, %job_id, %phase, "harness.job");
}
