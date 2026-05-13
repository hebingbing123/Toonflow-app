use axum::extract::ws::WebSocket;
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

use crate::harness::wire::HarnessAgentRunPayload;
use crate::harness::ws::agent::{self, HarnessAgentWsParams};
use crate::harness::ws::auth::WsConnectionSession;
use crate::harness::ws::channel::WsAgentChannel;
use crate::harness::ws::outbound::send_error;
use crate::state::AppState;

use crate::harness::ws::dispatch::envelope::ClientEnvelope;

pub(super) async fn harness_agent_run(
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
            "attach a channel before harness.agent.run",
            env.request_id.as_deref(),
        )
        .await;
        return;
    }
    let Ok(p) = serde_json::from_value::<HarnessAgentRunPayload>(env.payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need content string; optional max_tool_rounds (usize, default 8)",
            env.request_id.as_deref(),
        )
        .await;
        return;
    };
    let content = p.content.trim();
    if content.is_empty() {
        let _ = send_error(
            socket,
            "invalid_payload",
            "content must be non-empty",
            env.request_id.as_deref(),
        )
        .await;
        return;
    }

    if p.stream == Some(true) {
        let allowed = std::env::var("HARNESS_AGENT_STREAMING_TOOLS")
            .ok()
            .map(|s| {
                matches!(
                    s.trim().to_ascii_lowercase().as_str(),
                    "1" | "true" | "yes" | "on"
                )
            })
            .unwrap_or(false);
        if !allowed {
            let _ = send_error(
                socket,
                "not_implemented",
                "harness.agent.run payload.stream=true requires HARNESS_AGENT_STREAMING_TOOLS=1 (WP-E streaming tool fusion); omit stream or use false until enabled",
                env.request_id.as_deref(),
            )
            .await;
            return;
        }
        tracing::info!(
            target: "harness.agent",
            "WP-E: stream=true with HARNESS_AGENT_STREAMING_TOOLS — using non-streaming completion+tool loop until streamed deltas land"
        );
    }

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

    let max_rounds = p.max_tool_rounds.clamp(1, 32);
    let project_numeric_id = sess.project_id.and_then(|v| i32::try_from(v).ok());
    let script_numeric_id = sess.script_id.and_then(|v| i32::try_from(v).ok());
    agent::spawn_harness_agent_run(HarnessAgentWsParams {
        cfg,
        client: state.http_client.clone(),
        content: content.to_string(),
        assistant_name,
        user_id: sess.user_id,
        pool: state.pool.clone(),
        project_numeric_id,
        script_numeric_id,
        workspace_id: sess.workspace_id,
        max_rounds,
        stream: p.stream.unwrap_or(false),
        cancel,
        out_tx: out_tx.clone(),
        request_id: env.request_id.clone(),
        billing_config: state.billing_config.clone(),
    });
}
