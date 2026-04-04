//! Authenticated WebSocket JSON envelope parse + route to harness handlers.

use axum::extract::ws::WebSocket;
use serde::Deserialize;
use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

use crate::harness::wire::{ChatSendPayload, HarnessAgentRunPayload};
use crate::harness::ws_agent::{self, HarnessAgentWsParams};
use crate::harness::ws_auth::{self, WsConnectionSession};
use crate::harness::ws_channel::WsAgentChannel;
use crate::harness::ws_chat::{self, ChatTurnWsParams};
use crate::harness::ws_outbound::{send_envelope, send_error};
use crate::harness::ws_session::{self, WsSessionBindState};
use crate::harness::ws_tool;
use crate::harness::{observe, HarnessContext};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub(crate) struct ClientEnvelope {
    #[serde(rename = "type")]
    pub msg_type: String,
    pub schema_version: i32,
    pub payload: Value,
    pub request_id: Option<String>,
}

pub(crate) async fn dispatch_client_text(
    text: String,
    session: &mut Option<WsConnectionSession>,
    secret: &[u8],
    state: &AppState,
    socket: &mut WebSocket,
    out_tx: &UnboundedSender<String>,
) {
    let Ok(env): Result<ClientEnvelope, _> = serde_json::from_str(&text) else {
        let _ = send_error(socket, "invalid_json", "expected UTF-8 JSON envelope", None).await;
        return;
    };

    if env.schema_version != 1 {
        let _ = send_error(
            socket,
            "unsupported_schema",
            "only schema_version 1 is supported",
            env.request_id.as_deref(),
        )
        .await;
        return;
    }

    if session.is_none() {
        if env.msg_type != "session.auth" {
            let _ = send_error(
                socket,
                "unauthorized",
                "send session.auth or use ?access_token=",
                env.request_id.as_deref(),
            )
            .await;
            return;
        }

        if let Some(s) = ws_auth::try_session_auth(
            socket,
            secret,
            state,
            out_tx,
            &env.payload,
            env.request_id.as_deref(),
        )
        .await
        {
            *session = Some(s);
        }
        return;
    }

    let Some(sess) = session.as_mut() else {
        return;
    };

    let ctx = HarnessContext::new(sess.user_id);
    observe::ws_frame(&ctx, &env.msg_type);

    match env.msg_type.as_str() {
        "agent.script.attach" => {
            let mut st = WsSessionBindState {
                channel: &mut sess.channel,
                isolation_key: &mut sess.isolation_key,
                project_id: &mut sess.project_id,
                script_id: &mut sess.script_id,
            };
            ws_session::handle_script_attach(
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
            ws_session::handle_production_attach(
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
            ws_session::handle_context_update(
                socket,
                &mut st,
                &env.payload,
                env.request_id.as_deref(),
            )
            .await;
        }
        "harness.tool.invoke" => {
            ws_tool::handle_harness_tool_invoke(
                socket,
                &ctx,
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
            ws_agent::spawn_harness_agent_run(HarnessAgentWsParams {
                cfg,
                client: state.http_client.clone(),
                content: content.to_string(),
                assistant_name,
                user_id: sess.user_id,
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

            ws_chat::spawn_stream_chat_turn(ChatTurnWsParams {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn envelope_roundtrip() {
        let raw = r#"{"type":"session.auth","schema_version":1,"payload":{"access_token":"x"}}"#;
        let e: ClientEnvelope = serde_json::from_str(raw).unwrap();
        assert_eq!(e.msg_type, "session.auth");
        assert_eq!(e.schema_version, 1);
    }
}
