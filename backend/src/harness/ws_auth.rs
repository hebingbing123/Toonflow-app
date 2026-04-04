//! WebSocket session bootstrap: **`?access_token=`** (silent if invalid) and **`session.auth`** → **`session.ready`**.

use axum::extract::ws::WebSocket;
use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::auth::verify_supabase_user_jwt;
use crate::harness::wire::SessionAuthPayload;
use crate::harness::ws_channel::WsAgentChannel;
use crate::state::AppState;
use crate::ws::{send_envelope, send_error};

/// Per-WebSocket connection state (user id, agent attach, notify subscription, LLM cancel).
pub struct WsConnectionSession {
    pub user_id: Uuid,
    pub channel: Option<WsAgentChannel>,
    pub isolation_key: Option<String>,
    pub project_id: Option<i64>,
    pub script_id: Option<i64>,
    pub llm_cancel: CancellationToken,
    /// `(user_id, subscription_id)` for [`crate::notify_hub::WsNotifyHub`].
    pub ws_notify: Option<(Uuid, Uuid)>,
}

/// If the handshake URL carried **`access_token`**, verify JWT and return a session **without** notify subscription yet (caller subscribes and sets [`WsConnectionSession::ws_notify`]).
/// Invalid or missing token yields **`None`** (same as an anonymous connection until **`session.auth`**).
#[must_use]
pub fn session_from_query_access_token(
    raw: Option<&str>,
    secret: &[u8],
) -> Option<WsConnectionSession> {
    let raw = raw?;
    let claims = verify_supabase_user_jwt(raw, secret).ok()?;
    let uid = Uuid::parse_str(claims.sub.trim()).ok()?;
    Some(WsConnectionSession::new_authenticated(uid, None))
}

impl WsConnectionSession {
    #[must_use]
    pub fn new_authenticated(user_id: Uuid, ws_notify: Option<(Uuid, Uuid)>) -> Self {
        Self {
            user_id,
            channel: None,
            isolation_key: None,
            project_id: None,
            script_id: None,
            llm_cancel: CancellationToken::new(),
            ws_notify,
        }
    }
}

/// Complete **`session.auth`** after caller verified `session.is_none()` and `type == session.auth`.
/// On success returns [`WsConnectionSession`] and sends **`session.ready`**; on failure sends **`error.occurred`** and returns **`None`**.
pub async fn try_session_auth(
    socket: &mut WebSocket,
    secret: &[u8],
    state: &AppState,
    out_tx: &UnboundedSender<String>,
    payload: &Value,
    request_id: Option<&str>,
) -> Option<WsConnectionSession> {
    let Ok(auth) = serde_json::from_value::<SessionAuthPayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "session.auth requires payload.access_token",
            request_id,
        )
        .await;
        return None;
    };

    let Ok(claims) = verify_supabase_user_jwt(&auth.access_token, secret) else {
        let _ = send_error(
            socket,
            "invalid_token",
            "JWT verification failed",
            request_id,
        )
        .await;
        return None;
    };

    let Ok(uid) = Uuid::parse_str(claims.sub.trim()) else {
        let _ = send_error(socket, "invalid_token", "invalid sub claim", request_id).await;
        return None;
    };

    let conn_id = state.notify.subscribe(uid, out_tx.clone()).await;
    let session = WsConnectionSession::new_authenticated(uid, Some((uid, conn_id)));

    let _ = send_envelope(
        socket,
        "session.ready",
        1,
        json!({ "sub": uid.to_string() }),
        request_id,
    )
    .await;

    Some(session)
}
