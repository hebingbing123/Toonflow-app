use axum::extract::ws::WebSocket;

use crate::harness::ws::tool;
use crate::harness::HarnessContext;

use crate::harness::ws::dispatch::envelope::ClientEnvelope;

pub(super) async fn harness_tool_invoke(
    env: ClientEnvelope,
    ctx: &HarnessContext,
    socket: &mut WebSocket,
) {
    tool::handle_harness_tool_invoke(
        socket,
        ctx,
        env.schema_version,
        &env.payload,
        env.request_id.as_deref(),
    )
    .await;
}
