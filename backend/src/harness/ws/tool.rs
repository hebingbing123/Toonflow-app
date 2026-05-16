//! WebSocket 分支（`harness.tool.invoke` → `harness.tool.result` / `error.occurred`）。

use axum::extract::ws::WebSocket;
use serde_json::{json, Value};

use crate::harness::invoke;
use crate::harness::wire::HarnessToolInvokePayload;
use crate::harness::ws::outbound::{send_envelope, send_error};
use crate::harness::HarnessContext;

pub async fn handle_harness_tool_invoke(
    socket: &mut WebSocket,
    ctx: &HarnessContext,
    schema_version: i32,
    payload: &Value,
    request_id: Option<&str>,
) {
    if schema_version != 1 {
        let _ = send_error(
            socket,
            "unsupported_schema",
            "harness.tool.invoke requires schema_version 1",
            request_id,
        )
        .await;
        return;
    }
    let Ok(p) = serde_json::from_value::<HarnessToolInvokePayload>(payload.clone()) else {
        let _ = send_error(
            socket,
            "invalid_payload",
            "need payload.name (string) and optional payload.arguments (object)",
            request_id,
        )
        .await;
        return;
    };
    let name = p.name.trim();
    if name.is_empty() {
        let _ = send_error(
            socket,
            "invalid_payload",
            "payload.name must be a non-empty string",
            request_id,
        )
        .await;
        return;
    }
    let args = p.arguments.unwrap_or_else(|| json!({}));

    let span = tracing::info_span!(
        "harness.tool.invoke",
        tool_name = name,
        user_id = %ctx.user_id,
        workspace_id = ?ctx.workspace_id,
        request_id = request_id.unwrap_or("")
    );
    let _tool_enter = span.enter();

    match invoke::invoke_tool_async(ctx, name, &args).await {
        Ok(result) => {
            // Successful tool invocations answer with the same raw WS envelope family;
            // `payload.name` identifies the tool and `payload.result` carries its JSON return value.
            let _ = send_envelope(
                socket,
                "harness.tool.result",
                1,
                json!({ "name": name, "result": result }),
                request_id,
            )
            .await;
        }
        Err(e) => {
            let _ = send_error(socket, e.code(), &e.message(), request_id).await;
        }
    }
}
