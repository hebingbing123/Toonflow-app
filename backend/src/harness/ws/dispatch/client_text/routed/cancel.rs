use axum::extract::ws::WebSocket;
use serde_json::json;
use tokio_util::sync::CancellationToken;

use crate::harness::ws::auth::WsConnectionSession;
use crate::harness::ws::outbound::{send_envelope, send_error};

use crate::harness::ws::dispatch::envelope::ClientEnvelope;

pub(super) async fn agent_run_cancel(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    socket: &mut WebSocket,
) {
    sess.llm_cancel.cancel();
    sess.llm_cancel = CancellationToken::new();
    let _ = send_envelope(
        socket,
        "session.ack",
        1,
        json!({ "stopped": true }),
        env.request_id.as_deref(),
    )
    .await;
}

pub(super) async fn unknown_type(env: ClientEnvelope, socket: &mut WebSocket) {
    let _ = send_error(
        socket,
        "unknown_type",
        &format!("unknown type {}", env.msg_type),
        env.request_id.as_deref(),
    )
    .await;
}
