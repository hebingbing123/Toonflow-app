use super::HarnessContext;
use uuid::Uuid;

pub fn ws_frame(ctx: &HarnessContext, msg_type: &str) {
    tracing::debug!(user_id = %ctx.user_id, %msg_type, "harness.ws");
}

pub fn agent_llm_turn_requested(user_id: Uuid, content_len: usize) {
    tracing::info!(%user_id, content_len, "harness.agent_llm_turn");
}
