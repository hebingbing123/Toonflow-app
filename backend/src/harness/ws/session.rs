//! WebSocket 分支（`agent.script.attach`、`agent.production.attach`、`agent.context.update`）。

use axum::extract::ws::WebSocket;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::harness::permissions;
use crate::harness::wire::{AttachProductionPayload, AttachScriptPayload};
use crate::harness::ws::attach_resolve::{
    resolve_ws_attach_project, resolve_ws_attach_script_production,
};
use crate::harness::ws::channel::WsAgentChannel;
use crate::harness::ws::outbound::{send_envelope, send_error};

/// Mutable session fields shared by attach / context handlers.
pub struct WsSessionBindState<'a> {
    pub channel: &'a mut Option<WsAgentChannel>,
    pub isolation_key: &'a mut Option<String>,
    pub project_id: &'a mut Option<i64>,
    pub script_id: &'a mut Option<i64>,
}

fn api_error_to_ws(err: ApiError) -> (&'static str, String) {
    match err {
        ApiError::BadRequest(s) => ("bad_request", s),
        ApiError::NotFound => ("not_found", "resource not found".into()),
        ApiError::DatabaseError(s) => ("database_error", s),
        other => ("attach_error", format!("{other:?}")),
    }
}

async fn reply_attach_resolve_error(
    socket: &mut WebSocket,
    err: ApiError,
    request_id: Option<&str>,
) {
    let (code, msg) = api_error_to_ws(err);
    let _ = send_error(socket, code, &msg, request_id).await;
}

pub async fn handle_script_attach(
    socket: &mut WebSocket,
    user_id: Uuid,
    pool: Option<&PgPool>,
    st: &mut WsSessionBindState<'_>,
    payload: &Value,
    request_id: Option<&str>,
) {
    let Ok(p) = serde_json::from_value::<AttachScriptPayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need isolation_key plus projectUuid and/or legacy project_id",
            request_id,
        )
        .await;
        return;
    };
    if !permissions::ws_channel_allowed(user_id, "script") {
        let _ = send_error(socket, "forbidden", "script channel denied", request_id).await;
        return;
    }
    let resolved =
        match resolve_ws_attach_project(pool, user_id, p.project_uuid, p.project_id).await {
            Ok(r) => r,
            Err(e) => {
                reply_attach_resolve_error(socket, e, request_id).await;
                return;
            }
        };
    *st.channel = Some(WsAgentChannel::Script);
    *st.isolation_key = Some(p.isolation_key);
    *st.project_id = Some(i64::from(resolved.project_numeric));
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
    pool: Option<&PgPool>,
    st: &mut WsSessionBindState<'_>,
    payload: &Value,
    request_id: Option<&str>,
) {
    let Ok(p) = serde_json::from_value::<AttachProductionPayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need isolation_key plus project/script identifiers (UUID preferred)",
            request_id,
        )
        .await;
        return;
    };
    if !permissions::ws_channel_allowed(user_id, "production") {
        let _ = send_error(socket, "forbidden", "production channel denied", request_id).await;
        return;
    }
    let project = match resolve_ws_attach_project(pool, user_id, p.project_uuid, p.project_id).await
    {
        Ok(r) => r,
        Err(e) => {
            reply_attach_resolve_error(socket, e, request_id).await;
            return;
        }
    };
    let script_numeric = match resolve_ws_attach_script_production(
        pool,
        user_id,
        &project,
        p.script_uuid,
        p.script_id,
    )
    .await
    {
        Ok(n) => n,
        Err(e) => {
            reply_attach_resolve_error(socket, e, request_id).await;
            return;
        }
    };
    *st.channel = Some(WsAgentChannel::Production);
    *st.isolation_key = Some(p.isolation_key);
    *st.project_id = Some(i64::from(project.project_numeric));
    *st.script_id = Some(i64::from(script_numeric));
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
    user_id: Uuid,
    pool: Option<&PgPool>,
    st: &mut WsSessionBindState<'_>,
    payload: &Value,
    request_id: Option<&str>,
) {
    let Ok(p) = serde_json::from_value::<AttachProductionPayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need isolation_key plus project/script identifiers (UUID preferred)",
            request_id,
        )
        .await;
        return;
    };
    let project = match resolve_ws_attach_project(pool, user_id, p.project_uuid, p.project_id).await
    {
        Ok(r) => r,
        Err(e) => {
            reply_attach_resolve_error(socket, e, request_id).await;
            return;
        }
    };
    let script_numeric = match resolve_ws_attach_script_production(
        pool,
        user_id,
        &project,
        p.script_uuid,
        p.script_id,
    )
    .await
    {
        Ok(n) => n,
        Err(e) => {
            reply_attach_resolve_error(socket, e, request_id).await;
            return;
        }
    };
    *st.isolation_key = Some(p.isolation_key);
    *st.project_id = Some(i64::from(project.project_numeric));
    *st.script_id = Some(i64::from(script_numeric));
    let _ = send_envelope(socket, "session.ack", 1, json!({ "ok": true }), request_id).await;
}
