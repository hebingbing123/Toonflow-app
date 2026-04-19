use axum::extract::ws::WebSocket;

use crate::harness::ws::auth::WsConnectionSession;
use crate::harness::ws::session::{self, WsSessionBindState};

use crate::harness::ws::dispatch::envelope::ClientEnvelope;

pub(super) async fn script_attach(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    socket: &mut WebSocket,
) {
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

pub(super) async fn production_attach(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    socket: &mut WebSocket,
) {
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

pub(super) async fn context_update(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    socket: &mut WebSocket,
) {
    let mut st = WsSessionBindState {
        channel: &mut sess.channel,
        isolation_key: &mut sess.isolation_key,
        project_id: &mut sess.project_id,
        script_id: &mut sess.script_id,
    };
    session::handle_context_update(socket, &mut st, &env.payload, env.request_id.as_deref()).await;
}
