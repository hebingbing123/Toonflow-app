//! 入站文本帧：解析信封并按 `type` 分发。

mod routed;

use axum::extract::ws::WebSocket;
use tokio::sync::mpsc::UnboundedSender;

use crate::harness::ws::auth::{self, WsConnectionSession};
use crate::harness::ws::outbound::send_error;
use crate::harness::{observe, HarnessContext};
use crate::state::AppState;

use super::envelope::ClientEnvelope;

pub(crate) async fn dispatch_client_text(
    text: String,
    session: &mut Option<WsConnectionSession>,
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

        if let Some(s) = auth::try_session_auth(
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

    let span = tracing::info_span!(
        "harness.session",
        user_id = %sess.user_id,
        workspace_id = ?sess.workspace_id
    );
    let _session_enter = span.enter();

    let project_numeric_id = sess.project_id.and_then(|v| i32::try_from(v).ok());
    let script_numeric_id = sess.script_id.and_then(|v| i32::try_from(v).ok());
    let ctx = HarnessContext::with_runtime_scope(
        sess.user_id,
        state.pool.clone(),
        project_numeric_id,
        script_numeric_id,
        sess.workspace_id,
        state.llm.clone(),
        Some(state.http_client.clone()),
        state.billing_config.clone(),
    );
    observe::ws_frame(&ctx, &env.msg_type);

    routed::dispatch_authenticated(env, sess, &ctx, state, socket, out_tx).await;
}
