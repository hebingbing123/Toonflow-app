use crate::auth::verify_supabase_user_jwt;
use crate::harness::wire::{ChatSendPayload, HarnessAgentRunPayload};
use crate::harness::ws_agent::{self, HarnessAgentWsParams};
use crate::harness::ws_auth::{self, WsConnectionSession};
use crate::harness::ws_channel::WsAgentChannel;
use crate::harness::ws_chat::{self, ChatTurnWsParams};
use crate::harness::ws_session::{self, WsSessionBindState};
use crate::harness::ws_tool;
use crate::harness::{observe, HarnessContext};
use crate::state::AppState;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::IntoResponse;
use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct WsQuery {
    pub access_token: Option<String>,
}

pub async fn ws_upgrade(
    ws: WebSocketUpgrade,
    Query(query): Query<WsQuery>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, state, query.access_token))
}

#[derive(Debug, Deserialize)]
struct ClientEnvelope {
    #[serde(rename = "type")]
    msg_type: String,
    schema_version: i32,
    payload: Value,
    request_id: Option<String>,
}

type Session = WsConnectionSession;

pub(crate) async fn send_envelope(
    socket: &mut WebSocket,
    msg_type: &str,
    schema_version: i32,
    payload: Value,
    request_id: Option<&str>,
) -> bool {
    let mut v = json!({
        "type": msg_type,
        "schema_version": schema_version,
        "payload": payload,
    });
    if let Some(rid) = request_id {
        v["request_id"] = json!(rid);
    }
    let Ok(text) = serde_json::to_string(&v) else {
        return false;
    };
    socket.send(Message::Text(text.into())).await.is_ok()
}

pub(crate) async fn send_error(
    socket: &mut WebSocket,
    code: &str,
    message: &str,
    request_id: Option<&str>,
) -> bool {
    let mut payload = json!({
        "code": code,
        "message": message,
    });
    if let Some(rid) = request_id {
        payload["request_id"] = json!(rid);
    }
    send_envelope(socket, "error.occurred", 1, payload, request_id).await
}

pub(crate) fn error_occurred_json(code: &str, message: &str, request_id: Option<&str>) -> String {
    let mut inner = json!({
        "code": code,
        "message": message,
    });
    if let Some(r) = request_id {
        inner["request_id"] = json!(r);
    }
    let mut v = json!({
        "type": "error.occurred",
        "schema_version": 1,
        "payload": inner,
    });
    if let Some(r) = request_id {
        v["request_id"] = json!(r);
    }
    serde_json::to_string(&v).expect("json")
}

async fn handle_socket(mut socket: WebSocket, state: AppState, query_token: Option<String>) {
    let Some(secret) = state.jwt_secret.clone() else {
        let _ = send_error(
            &mut socket,
            "auth_not_configured",
            "SUPABASE_JWT_SECRET is not set",
            None,
        )
        .await;
        let _ = socket.close().await;
        return;
    };

    let secret = secret.as_slice();

    let mut session: Option<Session> = None;

    if let Some(ref raw) = query_token {
        if let Ok(claims) = verify_supabase_user_jwt(raw, secret) {
            if let Ok(uid) = Uuid::parse_str(claims.sub.trim()) {
                session = Some(WsConnectionSession::new_authenticated(uid, None));
            }
        }
    }

    let (out_tx, mut out_rx) = tokio::sync::mpsc::unbounded_channel::<String>();

    if let Some(ref mut s) = session {
        let cid = state.notify.subscribe(s.user_id, out_tx.clone()).await;
        s.ws_notify = Some((s.user_id, cid));
    }

    loop {
        tokio::select! {
            biased;
            maybe_out = out_rx.recv() => {
                let Some(text) = maybe_out else { break };
                if socket.send(Message::Text(text.into())).await.is_err() {
                    break;
                }
            }
            incoming = socket.next() => {
                let Some(result) = incoming else { break };
                let Ok(msg) = result else { break };

                match msg {
                    Message::Text(text) => {
                        dispatch_client_text(
                            text.to_string(),
                            &mut session,
                            secret,
                            &state,
                            &mut socket,
                            &out_tx,
                        )
                        .await;
                    }
                    Message::Ping(p) => {
                        let _ = socket.send(Message::Pong(p)).await;
                    }
                    Message::Close(_) => break,
                    Message::Pong(_) => {}
                    Message::Binary(_) => {
                        let _ = send_error(
                            &mut socket,
                            "unsupported_frame",
                            "only text JSON frames are accepted",
                            None,
                        )
                        .await;
                    }
                }
            }
        }
    }

    if let Some(s) = session {
        if let Some((uid, cid)) = s.ws_notify {
            state.notify.unsubscribe(uid, cid).await;
        }
    }
}

async fn dispatch_client_text(
    text: String,
    session: &mut Option<Session>,
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

    #[test]
    fn error_occurred_json_includes_request_id_in_payload() {
        let rid = "550e8400-e29b-41d4-a716-446655440000";
        let s = error_occurred_json("x", "y", Some(rid));
        let v: Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v.get("request_id").and_then(Value::as_str), Some(rid));
        let payload = v.get("payload").unwrap();
        assert_eq!(payload.get("request_id").and_then(Value::as_str), Some(rid));
        assert_eq!(payload.get("code").and_then(Value::as_str), Some("x"));
    }
}
