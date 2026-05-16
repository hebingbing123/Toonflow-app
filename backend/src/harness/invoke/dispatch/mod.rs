mod in_process;
mod sub_agent;

use serde_json::Value;

use crate::harness::HarnessContext;

use super::InvokeError;

use in_process::dispatch_in_process;
use sub_agent::is_sub_agent_tool;

/// Run a catalog tool by name. Returns JSON suitable for `harness.tool.result.payload.result`.
/// WebSocket uses [`invoke_tool_async`] (process-isolated tools); this remains for tests and a future sync caller.
#[allow(dead_code)]
pub fn invoke_tool(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    if !super::super::permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    super::super::observe::harness_tool_invoke(ctx, name);

    dispatch_in_process(ctx, name, arguments)
}

/// Like [`invoke_tool`], but routes process-isolated tools to async handlers (WebSocket path).
pub async fn invoke_tool_async(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    use super::domain_production::*;
    use super::domain_script::*;

    if !super::super::permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    super::super::observe::harness_tool_invoke(ctx, name);

    match name {
        "isolated.echo" => super::super::isolate::isolated_echo(arguments).await,
        "get_planData" => invoke_get_plan_data(ctx, arguments).await,
        "get_script_content" => invoke_get_script_content(ctx, arguments).await,
        "get_novel_text" => invoke_get_novel_text(ctx, arguments).await,
        "get_novel_events" => invoke_get_novel_events(ctx, arguments).await,
        "get_flowData" => invoke_get_flow_data(ctx, arguments).await,
        "add_deriveAsset" => invoke_add_derive_asset(ctx, arguments).await,
        "del_deriveAsset" => invoke_del_derive_asset(ctx, arguments).await,
        "generate_deriveAsset" => invoke_generate_derive_asset(ctx, arguments).await,
        "generate_storyboard" => invoke_generate_storyboard(ctx, arguments).await,
        _ if is_sub_agent_tool(name) => {
            super::super::sub_agent::invoke_sub_agent_tool(ctx, name, arguments).await
        }
        "wasm.probe" => {
            let r = tokio::task::spawn_blocking(super::super::wasm_runtime::invoke_probe)
                .await
                .map_err(|e| InvokeError::WasmFailed(format!("join: {e}")))?;
            r.map_err(InvokeError::WasmFailed)
        }
        "wasm.user.probe" => {
            super::super::user_wasm_probe::invoke_wasm_user_probe_tool(ctx, arguments).await
        }
        _ => dispatch_in_process(ctx, name, arguments),
    }
}
