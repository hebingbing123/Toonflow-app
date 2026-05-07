//! WebSocket 会话引导：`?access_token=`（无效时静默）和 `session.auth` → `session.ready`。

use axum::extract::ws::WebSocket;
use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::auth::verify_supabase_user_jwt;
use crate::harness::wire::SessionAuthPayload;
use crate::harness::ws::channel::WsAgentChannel;
use crate::harness::ws::outbound::{send_envelope, send_error};
use crate::state::AppState;

/// Per-WebSocket connection state (user id, agent attach, notify subscription, LLM cancel).
pub struct WsConnectionSession {
    pub user_id: Uuid,
    pub channel: Option<WsAgentChannel>,
    pub isolation_key: Option<String>,
    pub project_id: Option<i64>,
    pub script_id: Option<i64>,
    /// Resolved **`app_project.workspace_id`** after successful attach / context update (requires PG).
    pub workspace_id: Option<Uuid>,
    pub llm_cancel: CancellationToken,
    /// `(user_id, subscription_id)` for [`crate::state::WsNotifyHub`].
    pub ws_notify: Option<(Uuid, Uuid)>,
}

/// If the handshake URL carried **`access_token`**, verify JWT and return a session **without** notify subscription yet (call [`subscribe_notify_for_session`] once **`out_tx`** exists).
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
            workspace_id: None,
            llm_cancel: CancellationToken::new(),
            ws_notify,
        }
    }
}

/// Register this connection on [`AppState::notify`] when **`session`** is already authenticated (query token path).
pub async fn subscribe_notify_for_session(
    session: &mut Option<WsConnectionSession>,
    state: &AppState,
    out_tx: &UnboundedSender<String>,
) {
    if let Some(ref mut s) = session {
        let cid = state.notify.subscribe(s.user_id, out_tx.clone()).await;
        s.ws_notify = Some((s.user_id, cid));
    }
}

/// Best-effort teardown for [`WsConnectionSession::ws_notify`].
pub async fn unsubscribe_notify_if_any(session: Option<&WsConnectionSession>, state: &AppState) {
    if let Some(s) = session {
        if let Some((uid, cid)) = s.ws_notify {
            state.notify.unsubscribe(uid, cid).await;
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
