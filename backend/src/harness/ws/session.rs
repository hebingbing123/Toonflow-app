//! WebSocket 分支（`agent.script.attach`、`agent.production.attach`、`agent.context.update`）。

use axum::extract::ws::WebSocket;
use serde_json::{json, Value};
use uuid::Uuid;

use crate::harness::permissions;
use crate::harness::wire::{AttachProductionPayload, AttachScriptPayload};
use crate::harness::ws::channel::WsAgentChannel;
use crate::harness::ws::outbound::{send_envelope, send_error};

/// Mutable session fields shared by attach / context handlers.
pub struct WsSessionBindState<'a> {
    pub channel: &'a mut Option<WsAgentChannel>,
    pub isolation_key: &'a mut Option<String>,
    pub project_id: &'a mut Option<i64>,
    pub script_id: &'a mut Option<i64>,
}

pub async fn handle_script_attach(
    socket: &mut WebSocket,
    user_id: Uuid,
    st: &mut WsSessionBindState<'_>,
    payload: &Value,
    request_id: Option<&str>,
) {
    let Ok(p) = serde_json::from_value::<AttachScriptPayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need isolation_key, project_id",
            request_id,
        )
        .await;
        return;
    };
    if !permissions::ws_channel_allowed(user_id, "script") {
        let _ = send_error(socket, "forbidden", "script channel denied", request_id).await;
        return;
    }
    *st.channel = Some(WsAgentChannel::Script);
    *st.isolation_key = Some(p.isolation_key);
    *st.project_id = Some(p.project_id);
    *st.script_id = None;
    let _ = send_envelope(
        socket,
        "session.ack",
        1,
        json!({ "ok": true, "channel": "script" }),
        request_id,
    )
    .await;
}

pub async fn handle_production_attach(
    socket: &mut WebSocket,
    user_id: Uuid,
    st: &mut WsSessionBindState<'_>,
    payload: &Value,
    request_id: Option<&str>,
) {
    let Ok(p) = serde_json::from_value::<AttachProductionPayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need isolation_key, project_id, script_id",
            request_id,
        )
        .await;
        return;
    };
    if !permissions::ws_channel_allowed(user_id, "production") {
        let _ = send_error(socket, "forbidden", "production channel denied", request_id).await;
        return;
    }
    *st.channel = Some(WsAgentChannel::Production);
    *st.isolation_key = Some(p.isolation_key);
    *st.project_id = Some(p.project_id);
    *st.script_id = Some(p.script_id);
    let _ = send_envelope(
        socket,
        "session.ack",
        1,
        json!({ "ok": true, "channel": "production" }),
        request_id,
    )
    .await;
}

pub async fn handle_context_update(
    socket: &mut WebSocket,
    st: &mut WsSessionBindState<'_>,
    payload: &Value,
    request_id: Option<&str>,
) {
    let Ok(p) = serde_json::from_value::<AttachProductionPayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need isolation_key, project_id, script_id",
            request_id,
        )
        .await;
        return;
    };
    *st.isolation_key = Some(p.isolation_key);
    *st.project_id = Some(p.project_id);
    *st.script_id = Some(p.script_id);
    let _ = send_envelope(socket, "session.ack", 1, json!({ "ok": true }), request_id).await;
}
