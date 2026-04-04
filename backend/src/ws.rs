use crate::auth::verify_supabase_user_jwt;
use crate::harness::{observe, permissions, HarnessContext};
use crate::state::AppState;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::IntoResponse;
use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use serde_json::{json, Value};
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum WsChannel {
    Script,
    Production,
}

struct Session {
    user_id: Uuid,
    channel: Option<WsChannel>,
    isolation_key: Option<String>,
    project_id: Option<i64>,
    script_id: Option<i64>,
}

async fn send_envelope(
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

async fn send_error(
    socket: &mut WebSocket,
    code: &str,
    message: &str,
    request_id: Option<&str>,
) -> bool {
    let payload = json!({
        "code": code,
        "message": message,
    });
    send_envelope(socket, "error.occurred", 1, payload, request_id).await
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
                session = Some(Session {
                    user_id: uid,
                    channel: None,
                    isolation_key: None,
                    project_id: None,
                    script_id: None,
                });
            }
        }
    }

    while let Some(result) = socket.next().await {
        let Ok(msg) = result else {
            break;
        };

        match msg {
            Message::Text(text) => {
                let Ok(env): Result<ClientEnvelope, _> = serde_json::from_str(&text) else {
                    let _ = send_error(
                        &mut socket,
                        "invalid_json",
                        "expected UTF-8 JSON envelope",
                        None,
                    )
                    .await;
                    continue;
                };

                if env.schema_version != 1 {
                    let _ = send_error(
                        &mut socket,
                        "unsupported_schema",
                        "only schema_version 1 is supported",
                        env.request_id.as_deref(),
                    )
                    .await;
                    continue;
                }

                if session.is_none() {
                    if env.msg_type != "session.auth" {
                        let _ = send_error(
                            &mut socket,
                            "unauthorized",
                            "send session.auth or use ?access_token=",
                            env.request_id.as_deref(),
                        )
                        .await;
                        continue;
                    }

                    let Ok(auth) =
                        serde_json::from_value::<SessionAuthPayload>(env.payload.clone())
                    else {
                        let _ = send_error(
                            &mut socket,
                            "invalid_payload",
                            "session.auth requires payload.access_token",
                            env.request_id.as_deref(),
                        )
                        .await;
                        continue;
                    };

                    let Ok(claims) = verify_supabase_user_jwt(&auth.access_token, secret) else {
                        let _ = send_error(
                            &mut socket,
                            "invalid_token",
                            "JWT verification failed",
                            env.request_id.as_deref(),
                        )
                        .await;
                        continue;
                    };

                    let Ok(uid) = Uuid::parse_str(claims.sub.trim()) else {
                        let _ = send_error(
                            &mut socket,
                            "invalid_token",
                            "invalid sub claim",
                            env.request_id.as_deref(),
                        )
                        .await;
                        continue;
                    };

                    session = Some(Session {
                        user_id: uid,
                        channel: None,
                        isolation_key: None,
                        project_id: None,
                        script_id: None,
                    });

                    let _ = send_envelope(
                        &mut socket,
                        "session.ready",
                        1,
                        json!({ "sub": uid.to_string() }),
                        env.request_id.as_deref(),
                    )
                    .await;
                    continue;
                }

                let Some(sess) = session.as_mut() else {
                    continue;
                };

                let ctx = HarnessContext::new(sess.user_id);
                observe::ws_frame(&ctx, &env.msg_type);

                match env.msg_type.as_str() {
                    "agent.script.attach" => {
                        let Ok(p) =
                            serde_json::from_value::<AttachScriptPayload>(env.payload.clone())
                        else {
                            let _ = send_error(
                                &mut socket,
                                "invalid_payload",
                                "need isolation_key, project_id",
                                env.request_id.as_deref(),
                            )
                            .await;
                            continue;
                        };
                        if !permissions::ws_channel_allowed(sess.user_id, "script") {
                            let _ = send_error(
                                &mut socket,
                                "forbidden",
                                "script channel denied",
                                env.request_id.as_deref(),
                            )
                            .await;
                            continue;
                        }
                        sess.channel = Some(WsChannel::Script);
                        sess.isolation_key = Some(p.isolation_key);
                        sess.project_id = Some(p.project_id);
                        sess.script_id = None;
                        let _ = send_envelope(
                            &mut socket,
                            "session.ack",
                            1,
                            json!({ "ok": true, "channel": "script" }),
                            env.request_id.as_deref(),
                        )
                        .await;
                    }
                    "agent.production.attach" => {
                        let Ok(p) =
                            serde_json::from_value::<AttachProductionPayload>(env.payload.clone())
                        else {
                            let _ = send_error(
                                &mut socket,
                                "invalid_payload",
                                "need isolation_key, project_id, script_id",
                                env.request_id.as_deref(),
                            )
                            .await;
                            continue;
                        };
                        if !permissions::ws_channel_allowed(sess.user_id, "production") {
                            let _ = send_error(
                                &mut socket,
                                "forbidden",
                                "production channel denied",
                                env.request_id.as_deref(),
                            )
                            .await;
                            continue;
                        }
                        sess.channel = Some(WsChannel::Production);
                        sess.isolation_key = Some(p.isolation_key);
                        sess.project_id = Some(p.project_id);
                        sess.script_id = Some(p.script_id);
                        let _ = send_envelope(
                            &mut socket,
                            "session.ack",
                            1,
                            json!({ "ok": true, "channel": "production" }),
                            env.request_id.as_deref(),
                        )
                        .await;
                    }
                    "agent.context.update" => {
                        let Ok(p) =
                            serde_json::from_value::<AttachProductionPayload>(env.payload.clone())
                        else {
                            let _ = send_error(
                                &mut socket,
                                "invalid_payload",
                                "need isolation_key, project_id, script_id",
                                env.request_id.as_deref(),
                            )
                            .await;
                            continue;
                        };
                        sess.isolation_key = Some(p.isolation_key);
                        sess.project_id = Some(p.project_id);
                        sess.script_id = Some(p.script_id);
                        let _ = send_envelope(
                            &mut socket,
                            "session.ack",
                            1,
                            json!({ "ok": true }),
                            env.request_id.as_deref(),
                        )
                        .await;
                    }
                    "agent.chat.send" => {
                        if sess.channel.is_none() {
                            let _ = send_error(
                                &mut socket,
                                "invalid_state",
                                "attach a channel before chat",
                                env.request_id.as_deref(),
                            )
                            .await;
                            continue;
                        }
                        let Ok(p) = serde_json::from_value::<ChatSendPayload>(env.payload.clone())
                        else {
                            let _ = send_error(
                                &mut socket,
                                "invalid_payload",
                                "need content string",
                                env.request_id.as_deref(),
                            )
                            .await;
                            continue;
                        };
                        observe::agent_chat_stub(sess.user_id, p.content.len());
                        let _ = send_envelope(
                            &mut socket,
                            "agent.chat.stub",
                            1,
                            json!({
                                "received": true,
                                "hint": "LLM/agent loop not wired yet"
                            }),
                            env.request_id.as_deref(),
                        )
                        .await;
                    }
                    "agent.run.cancel" => {
                        let _ = send_envelope(
                            &mut socket,
                            "session.ack",
                            1,
                            json!({ "stopped": true }),
                            env.request_id.as_deref(),
                        )
                        .await;
                    }
                    _ => {
                        let _ = send_error(
                            &mut socket,
                            "unknown_type",
                            &format!("unknown type {}", env.msg_type),
                            env.request_id.as_deref(),
                        )
                        .await;
                    }
                }
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

#[derive(Debug, Deserialize)]
struct SessionAuthPayload {
    access_token: String,
}

#[derive(Debug, Deserialize)]
struct AttachScriptPayload {
    isolation_key: String,
    project_id: i64,
}

#[derive(Debug, Deserialize)]
struct AttachProductionPayload {
    isolation_key: String,
    project_id: i64,
    script_id: i64,
}

#[derive(Debug, Deserialize)]
struct ChatSendPayload {
    content: String,
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
