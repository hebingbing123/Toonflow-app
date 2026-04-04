//! Single WebSocket connection after Axum upgrade: outbound notify fan-in + inbound JSON dispatch.

use axum::extract::ws::{Message, WebSocket};
use futures_util::{SinkExt, StreamExt};

use crate::harness::ws_auth::{self, WsConnectionSession};
use crate::harness::ws_dispatch;
use crate::state::AppState;
use crate::ws::send_error;

pub(crate) async fn run_socket(
    mut socket: WebSocket,
    state: AppState,
    query_token: Option<String>,
) {
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

    let mut session: Option<WsConnectionSession> =
        ws_auth::session_from_query_access_token(query_token.as_deref(), secret);

    let (out_tx, mut out_rx) = tokio::sync::mpsc::unbounded_channel::<String>();

    ws_auth::subscribe_notify_for_session(&mut session, &state, &out_tx).await;

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
                        ws_dispatch::dispatch_client_text(
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

    ws_auth::unsubscribe_notify_if_any(session.as_ref(), &state).await;
}
