use serde_json::Value;

use crate::harness::HarnessContext;

use super::super::InvokeError;
use super::sub_agent::is_sub_agent_tool;

pub(super) fn dispatch_in_process(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    use super::super::domain_production::*;
    use super::super::domain_script::*;

    match name {
        "echo" => Ok(arguments.clone()),
        "wasm.probe" => {
            super::super::super::wasm_runtime::invoke_probe().map_err(InvokeError::WasmFailed)
        }
        "wasm.user.probe" => Err(InvokeError::NotImplemented {
            tool: "wasm.user.probe".into(),
            hint: "use WebSocket harness.tool.invoke (async path)".into(),
        }),
        "skills.read" => {
            let path = arguments
                .get("path")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .ok_or_else(|| {
                    InvokeError::InvalidArgs(
                        "skills.read requires arguments.path (non-empty string)".into(),
                    )
                })?;
            let doc =
                crate::prompting::skills::read_skill_markdown(path).map_err(InvokeError::from)?;
            serde_json::to_value(&doc).map_err(|_| {
                InvokeError::SkillBadRequest("failed to serialize skill content".into())
            })
        }
        "get_planData" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_planData requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_plan_data(ctx, arguments))
        }
        "get_script_content" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_script_content requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_script_content(ctx, arguments))
        }
        "get_novel_text" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_novel_text requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_novel_text(ctx, arguments))
        }
        "get_novel_events" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_novel_events requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_novel_events(ctx, arguments))
        }
        "get_flowData" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_flowData requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_flow_data(ctx, arguments))
        }
        "add_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "add_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_add_derive_asset(ctx, arguments))
        }
        "del_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "del_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_del_derive_asset(ctx, arguments))
        }
        "generate_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "generate_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_generate_derive_asset(ctx, arguments))
        }
        "generate_storyboard" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "generate_storyboard requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_generate_storyboard(ctx, arguments))
        }
        _ if is_sub_agent_tool(name) => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "sub-agent tools require async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(super::super::super::sub_agent::invoke_sub_agent_tool(
                ctx, name, arguments,
            ))
        }
        _ => Err(InvokeError::NotImplemented {
            tool: name.to_string(),
            hint: "registered in catalog but execution is not wired yet".to_string(),
        }),
    }
}
