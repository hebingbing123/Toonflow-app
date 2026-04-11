//! Harness 代理的多轮 OpenAI 工具调用循环（非流式补全）。

use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::harness::invoke::invoke_tool_async;
use crate::harness::tools::ToolRegistry;
use crate::harness::HarnessContext;
use crate::llm::LlmConfig;

use super::envelope::envelope;

fn tool_parameters_schema(name: &str) -> Value {
    match name {
        "skills.read" => json!({
            "type": "object",
            "required": ["path"],
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Relative path under data/skills (same rules as REST GET /api/v1/skills/content)"
                }
            },
            "additionalProperties": false
        }),
        "get_script_content" => json!({
            "type": "object",
            "properties": {
                "scriptId": {
                    "type": "integer",
                    "description": "Legacy script id under the attached project; optional when attached production context already contains script_id."
                }
            },
            "additionalProperties": false
        }),
        "get_planData" => json!({
            "type": "object",
            "description": "No arguments required; reads scriptAgent plan data for the attached project context.",
            "additionalProperties": false
        }),
        "get_novel_text" | "get_novel_events" => json!({
            "type": "object",
            "properties": {
                "novelId": {
                    "type": "integer",
                    "description": "Optional legacy novel id to narrow results within the attached project."
                }
            },
            "additionalProperties": false
        }),
        "get_flowData" => json!({
            "type": "object",
            "required": ["key"],
            "properties": {
                "key": {
                    "type": "string",
                    "enum": ["script", "scriptPlan", "assets", "storyboardTable", "storyboard", "stoaryTable"],
                    "description": "Production workbench flow data key (`stoaryTable` is accepted as legacy typo alias)."
                },
                "scriptId": {
                    "type": "integer",
                    "description": "Optional legacy script id; defaults to attached script context."
                }
            },
            "additionalProperties": false
        }),
        "add_deriveAsset" => json!({
            "type": "object",
            "required": ["assetsId", "name", "desc"],
            "properties": {
                "assetsId": { "type": "integer", "description": "Parent asset legacy id." },
                "id": { "type": ["integer", "null"], "description": "Derived asset legacy id; null means create new." },
                "name": { "type": "string" },
                "desc": { "type": "string" },
                "scriptId": { "type": "integer", "description": "Optional legacy script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "del_deriveAsset" => json!({
            "type": "object",
            "required": ["assetsId", "id"],
            "properties": {
                "assetsId": { "type": "integer", "description": "Parent asset legacy id." },
                "id": { "type": "integer", "description": "Derived asset legacy id to delete." },
                "scriptId": { "type": "integer", "description": "Optional legacy script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "generate_deriveAsset" => json!({
            "type": "object",
            "required": ["ids"],
            "properties": {
                "ids": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "minItems": 1,
                    "description": "Derived asset legacy ids."
                },
                "model": { "type": "string" },
                "resolution": { "type": "string" },
                "scriptId": { "type": "integer", "description": "Optional legacy script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "generate_storyboard" => json!({
            "type": "object",
            "required": ["ids"],
            "properties": {
                "ids": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "minItems": 1,
                    "description": "Storyboard legacy ids."
                },
                "model": { "type": "string" },
                "resolution": { "type": "string" },
                "scriptId": { "type": "integer", "description": "Optional legacy script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "run_sub_agent_storySkeleton"
        | "run_sub_agent_adaptationStrategy"
        | "run_sub_agent_script"
        | "run_supervision_agent"
        | "run_sub_agent_derive_assets"
        | "run_sub_agent_generate_assets"
        | "run_sub_agent_director_plan"
        | "run_sub_agent_storyboard_gen"
        | "run_sub_agent_storyboard_panel"
        | "run_sub_agent_storyboard_table" => json!({
            "type": "object",
            "required": ["prompt"],
            "properties": {
                "prompt": {
                    "type": "string",
                    "description": "Sub-agent task prompt (concise instruction, <= 2000 chars)."
                }
            },
            "additionalProperties": false
        }),
        _ => json!({
            "type": "object",
            "description": "JSON arguments for this tool (echo / isolated.echo accept any shape; wasm.probe ignores args)",
            "additionalProperties": true
        }),
    }
}

/// OpenAI Chat Completions `tools` array built from the static Harness catalog.
#[must_use]
pub fn harness_openai_tools() -> Vec<Value> {
    ToolRegistry::catalog()
        .iter()
        .map(|t| {
            json!({
                "type": "function",
                "function": {
                    "name": t.name,
                    "description": t.description,
                    "parameters": tool_parameters_schema(t.name),
                }
            })
        })
        .collect()
}

async fn post_completion(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: &[Value],
    tools: &[Value],
) -> Result<Value, String> {
    let url = format!("{}/chat/completions", cfg.base_url);
    let body = json!({
        "model": cfg.model,
        "stream": false,
        "messages": messages,
        "tools": tools,
        "tool_choice": "auto",
    });
    let response = client
        .post(&url)
        .header("Authorization", format!("Bearer {}", cfg.api_key))
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("llm request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        return Err(format!("llm HTTP {status}: {text}"));
    }
    response.json().await.map_err(|e| format!("llm json: {e}"))
}

fn emit_final_assistant_chat(
    out: &UnboundedSender<String>,
    full_text: &str,
    assistant_name: &str,
    request_id: Option<&str>,
) {
    let message_id = Uuid::new_v4();
    let content_id = Uuid::new_v4();
    let _ = out.send(envelope(
        "chat.message.created",
        json!({
            "id": message_id.to_string(),
            "role": "assistant",
            "name": assistant_name,
            "status": "streaming",
            "datetime": chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
            "content": [],
        }),
        request_id,
    ));
    let _ = out.send(envelope(
        "chat.content.added",
        json!({
            "messageId": message_id.to_string(),
            "content": {
                "type": "text",
                "id": content_id.to_string(),
                "data": "",
                "status": "pending",
            }
        }),
        request_id,
    ));
    if !full_text.is_empty() {
        let _ = out.send(envelope(
            "chat.content.updated",
            json!({
                "messageId": message_id.to_string(),
                "contentId": content_id.to_string(),
                "append": full_text,
            }),
            request_id,
        ));
    }
    let _ = out.send(envelope(
        "chat.message.updated",
        json!({
            "id": message_id.to_string(),
            "status": "complete",
        }),
        request_id,
    ));
}

/// Runs up to **`max_tool_rounds`** LLM completion calls, executing Harness tools and emitting
/// `harness.*` plus final `chat.message.*` envelopes (same family as streaming chat).
#[allow(clippy::too_many_arguments)]
pub async fn harness_agent_run(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    user_message: &str,
    assistant_name: &str,
    ctx: &HarnessContext,
    max_tool_rounds: usize,
    cancel: CancellationToken,
    out: UnboundedSender<String>,
    request_id: Option<&str>,
) -> Result<(), String> {
    let tools = harness_openai_tools();
    let system = format!(
        "You are the Toonflow harness agent ({assistant_name}). \
         Tools match GET /api/v1/harness/tools. \
         Use tools when asked to read a skill file, inspect script plan/content, test echo / isolated echo, or run the WASM probe. \
         After tools succeed, answer briefly in natural language."
    );
    let mut messages: Vec<Value> = vec![
        json!({ "role": "system", "content": system }),
        json!({ "role": "user", "content": user_message }),
    ];

    let _ = out.send(envelope(
        "harness.agent.started",
        json!({ "max_tool_rounds": max_tool_rounds }),
        request_id,
    ));

    let mut tool_rounds_executed: u32 = 0;

    for _ in 0..max_tool_rounds {
        let v = tokio::select! {
            _ = cancel.cancelled() => {
                let _ = out.send(envelope(
                    "harness.agent.cancelled",
                    json!({ "tool_rounds_executed": tool_rounds_executed }),
                    request_id,
                ));
                return Ok(());
            }
            res = post_completion(cfg, client, &messages, &tools) => res?,
        };

        let msg = v
            .get("choices")
            .and_then(|c| c.as_array())
            .and_then(|a| a.first())
            .and_then(|c| c.get("message"))
            .ok_or_else(|| "llm: missing choices[0].message".to_string())?;

        if let Some(tcs) = msg
            .get("tool_calls")
            .and_then(|x| x.as_array())
            .filter(|a| !a.is_empty())
        {
            messages.push(msg.clone());
            for tc in tcs {
                let id = tc
                    .get("id")
                    .and_then(|x| x.as_str())
                    .unwrap_or("call_unknown");
                let func = tc.get("function");
                let name = func
                    .and_then(|f| f.get("name"))
                    .and_then(|x| x.as_str())
                    .unwrap_or("")
                    .trim();
                let args_str = func
                    .and_then(|f| f.get("arguments"))
                    .and_then(|x| x.as_str())
                    .unwrap_or("{}");
                let args: Value = serde_json::from_str(args_str)
                    .unwrap_or_else(|_| json!({ "parse_error": true, "raw": args_str }));

                let _ = out.send(envelope(
                    "harness.agent.tool_call",
                    json!({ "call_id": id, "name": name, "arguments": args }),
                    request_id,
                ));

                let tool_result = match invoke_tool_async(ctx, name, &args).await {
                    Ok(r) => r,
                    Err(e) => json!({ "error": e.code(), "message": e.message() }),
                };

                let _ = out.send(envelope(
                    "harness.tool.result",
                    json!({ "name": name, "result": tool_result.clone() }),
                    request_id,
                ));

                let content = serde_json::to_string(&tool_result).unwrap_or_else(|_| "{}".into());
                messages.push(json!({
                    "role": "tool",
                    "tool_call_id": id,
                    "content": content,
                }));
            }
            tool_rounds_executed = tool_rounds_executed.saturating_add(1);
            continue;
        }

        let content = msg
            .get("content")
            .and_then(|x| match x {
                Value::String(s) => Some(s.clone()),
                Value::Null => None,
                other => Some(other.to_string()),
            })
            .unwrap_or_default();

        emit_final_assistant_chat(&out, &content, assistant_name, request_id);
        let _ = out.send(envelope(
            "harness.agent.finished",
            json!({
                "tool_rounds_executed": tool_rounds_executed,
                "finish_reason": "stop"
            }),
            request_id,
        ));
        return Ok(());
    }

    Err(format!(
        "harness agent: exceeded {max_tool_rounds} tool rounds without a final assistant message"
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn openai_tools_match_catalog_size() {
        assert_eq!(
            harness_openai_tools().len(),
            ToolRegistry::catalog().len(),
            "keep tool schemas in sync with GET /api/v1/harness/tools"
        );
    }
}
