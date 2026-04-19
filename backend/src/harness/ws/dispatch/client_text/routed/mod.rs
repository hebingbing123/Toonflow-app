//! Authenticated client envelope dispatch by `msg_type`.

mod agent_run;
mod attach;
mod cancel;
mod chat;
mod tool;

use axum::extract::ws::WebSocket;
use tokio::sync::mpsc::UnboundedSender;

use crate::harness::ws::auth::WsConnectionSession;
use crate::harness::HarnessContext;
use crate::state::AppState;

use crate::harness::ws::dispatch::envelope::ClientEnvelope;

pub(super) async fn dispatch_authenticated(
    env: ClientEnvelope,
    sess: &mut WsConnectionSession,
    ctx: &HarnessContext,
    state: &AppState,
    socket: &mut WebSocket,
    out_tx: &UnboundedSender<String>,
) {
    match env.msg_type.as_str() {
        "agent.script.attach" => {
            attach::script_attach(env, sess, socket).await;
        }
        "agent.production.attach" => {
            attach::production_attach(env, sess, socket).await;
        }
        "agent.context.update" => {
            attach::context_update(env, sess, socket).await;
        }
        "harness.tool.invoke" => {
            tool::harness_tool_invoke(env, ctx, socket).await;
        }
        "harness.agent.run" => {
            agent_run::harness_agent_run(env, sess, state, out_tx, socket).await;
        }
        "agent.chat.send" => {
            chat::agent_chat_send(env, sess, state, out_tx, socket).await;
        }
        "agent.run.cancel" => {
            cancel::agent_run_cancel(env, sess, socket).await;
        }
        _ => {
            cancel::unknown_type(env, socket).await;
        }
    }
}
