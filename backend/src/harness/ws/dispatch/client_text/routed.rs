use axum::extract::ws::WebSocket;
use serde_json::json;
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

use crate::harness::wire::{ChatSendPayload, HarnessAgentRunPayload};
use crate::harness::ws::agent::{self, HarnessAgentWsParams};
use crate::harness::ws::auth::WsConnectionSession;
use crate::harness::ws::channel::WsAgentChannel;
use crate::harness::ws::chat::{self, ChatTurnWsParams};
use crate::harness::ws::outbound::{send_envelope, send_error};
use crate::harness::ws::session::{self, WsSessionBindState};
use crate::harness::ws::tool;
use crate::harness::HarnessContext;
use crate::state::AppState;

use super::super::envelope::ClientEnvelope;

pub(super) async fn dispatch_authenticated(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    ctx: &HarnessContext,
    state: &AppState,
    socket: &mut WebSocket,
    out_tx: &UnboundedSender<String>,
) {
    let project_numeric_id = sess.project_id.and_then(|v| i32::try_from(v).ok());
    let script_numeric_id = sess.script_id.and_then(|v| i32::try_from(v).ok());

    match env.msg_type.as_str() {
        "agent.script.attach" => {
            let mut st = WsSessionBindState {
                channel: &mut sess.channel,
                isolation_key: &mut sess.isolation_key,
                project_id: &mut sess.project_id,
                script_id: &mut sess.script_id,
            };
            session::handle_script_attach(
                socket,
                sess.user_id,
                &mut st,
                &env.payload,
                env.request_id.as_deref(),
            )
            .await;
        }
        "agent.production.attach" => {
            let mut st = WsSessionBindState {
                channel: &mut sess.channel,
                isolation_key: &mut sess.isolation_key,
                project_id: &mut sess.project_id,
                script_id: &mut sess.script_id,
            };
            session::handle_production_attach(
                socket,
                sess.user_id,
                &mut st,
                &env.payload,
                env.request_id.as_deref(),
            )
            .await;
        }
        "agent.context.update" => {
            let mut st = WsSessionBindState {
                channel: &mut sess.channel,
                isolation_key: &mut sess.isolation_key,
                project_id: &mut sess.project_id,
                script_id: &mut sess.script_id,
            };
            session::handle_context_update(
                socket,
                &mut st,
                &env.payload,
                env.request_id.as_deref(),
            )
            .await;
        }
        "harness.tool.invoke" => {
            tool::handle_harness_tool_invoke(
                socket,
                ctx,
                env.schema_version,
                &env.payload,
                env.request_id.as_deref(),
            )
            .await;
        }
        "harness.agent.run" => {
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
            let Ok(p) = serde_json::from_value::<HarnessAgentRunPayload>(env.payload.clone())
            else {
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
            agent::spawn_harness_agent_run(HarnessAgentWsParams {
                cfg,
                client: state.http_client.clone(),
                content: content.to_string(),
                assistant_name,
                user_id: sess.user_id,
                pool: state.pool.clone(),
                project_numeric_id,
                script_numeric_id,
                max_rounds,
                cancel,
                out_tx: out_tx.clone(),
                request_id: env.request_id.clone(),
            });
        }
        "agent.chat.send" => {
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
        "agent.run.cancel" => {
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
        _ => {
            let _ = send_error(
                socket,
                "unknown_type",
                &format!("unknown type {}", env.msg_type),
                env.request_id.as_deref(),
            )
            .await;
        }
    }
}
