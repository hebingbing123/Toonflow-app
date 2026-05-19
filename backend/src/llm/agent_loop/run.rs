//! Harness 代理多轮工具调用主循环。

use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

use crate::harness::invoke::invoke_tool_async;
use crate::harness::HarnessContext;
use crate::llm::envelope::envelope;
use crate::llm::LlmConfig;

use super::client::post_completion;
use super::emit::emit_final_assistant_chat;
use super::schemas::harness_openai_tools;

/// Runs up to **`max_tool_rounds`** LLM completion calls, executing Harness tools and emitting
/// raw WS `harness.*` plus final `chat.message.*` envelopes (same family as streaming chat).
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
        "You are the Openflow harness agent ({assistant_name}). \
         Tools match GET /api/v1/harness/tools. \
         Use tools when asked to read a skill file, inspect script plan/content, test echo / isolated echo, or run the WASM probe. \
         Prefer the narrowest possible tool call first: use field subsets, paging, id lists, or text windows before full payloads. \
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
