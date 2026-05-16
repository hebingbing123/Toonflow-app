use axum::extract::ws::WebSocket;
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

use crate::harness::wire::ChatSendPayload;
use crate::harness::ws::auth::WsConnectionSession;
use crate::harness::ws::channel::WsAgentChannel;
use crate::harness::ws::chat::{self, ChatTurnWsParams};
use crate::harness::ws::outbound::send_error;
use crate::state::AppState;

use crate::harness::ws::dispatch::envelope::ClientEnvelope;

pub(super) async fn agent_chat_send(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    state: &AppState,
    out_tx: &UnboundedSender<String>,
    socket: &mut WebSocket,
) {
    if sess.channel.is_none() {
        let _ = send_error(
            socket,
            "invalid_state",
            "attach a channel before chat",
            env.request_id.as_deref(),
        )
        .await;
        return;
    }
    let Ok(p) = serde_json::from_value::<ChatSendPayload>(env.payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need content string",
            env.request_id.as_deref(),
        )
        .await;
        return;
    };

    let Some(cfg) = state.llm.clone() else {
        let _ = send_error(
            socket,
            "llm_not_configured",
            "set OPENAI_API_KEY or LLM_API_KEY",
            env.request_id.as_deref(),
        )
        .await;
        return;
    };

    sess.llm_cancel.cancel();
    sess.llm_cancel = CancellationToken::new();
    let cancel = sess.llm_cancel.clone();

    let assistant_name = sess
        .channel
        .map(WsAgentChannel::assistant_name_zh)
        .expect("channel checked above");

    chat::spawn_stream_chat_turn(ChatTurnWsParams {
        cfg,
        client: state.http_client.clone(),
        content: p.content.clone(),
        assistant_name,
        user_id: sess.user_id,
        cancel,
        out_tx: out_tx.clone(),
        request_id: env.request_id.clone(),
    });
}
