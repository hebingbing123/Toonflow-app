use axum::extract::ws::WebSocket;

use crate::harness::ws::auth::WsConnectionSession;
use crate::harness::ws::session::{self, WsSessionBindState};
use crate::state::AppState;

use crate::harness::ws::dispatch::envelope::ClientEnvelope;

pub(super) async fn script_attach(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    state: &AppState,
    socket: &mut WebSocket,
) {
    let mut st = WsSessionBindState {
        channel: &mut sess.channel,
        isolation_key: &mut sess.isolation_key,
        project_id: &mut sess.project_id,
        script_id: &mut sess.script_id,
        workspace_id: &mut sess.workspace_id,
    };
    session::handle_script_attach(
        socket,
        sess.user_id,
        state.pool.as_ref(),
        &mut st,
        &env.payload,
        env.request_id.as_deref(),
    )
    .await;
}

pub(super) async fn production_attach(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    state: &AppState,
    socket: &mut WebSocket,
) {
    let mut st = WsSessionBindState {
        channel: &mut sess.channel,
        isolation_key: &mut sess.isolation_key,
        project_id: &mut sess.project_id,
        script_id: &mut sess.script_id,
        workspace_id: &mut sess.workspace_id,
    };
    session::handle_production_attach(
        socket,
        sess.user_id,
        state.pool.as_ref(),
        &mut st,
        &env.payload,
        env.request_id.as_deref(),
    )
    .await;
}

pub(super) async fn context_update(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    state: &AppState,
    socket: &mut WebSocket,
) {
    let mut st = WsSessionBindState {
        channel: &mut sess.channel,
        isolation_key: &mut sess.isolation_key,
        project_id: &mut sess.project_id,
        script_id: &mut sess.script_id,
        workspace_id: &mut sess.workspace_id,
    };
    session::handle_context_update(
        socket,
        sess.user_id,
        state.pool.as_ref(),
        &mut st,
        &env.payload,
        env.request_id.as_deref(),
    )
    .await;
}
