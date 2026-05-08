use futures_util::StreamExt;
use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::harness::invoke::invoke_tool_async;
use crate::harness::HarnessContext;
use crate::llm::envelope::envelope;
use crate::llm::LlmConfig;

use super::schemas::harness_openai_tools;

#[derive(Debug, Clone, Default)]
struct ToolCallAccum {
    id: String,
    name: String,
    arguments: String,
}

fn apply_tool_call_deltas(calls: &mut Vec<ToolCallAccum>, deltas: &[Value]) {
    for tc in deltas {
        let index = tc.get("index").and_then(|x| x.as_u64()).unwrap_or(0) as usize;
        if calls.len() <= index {
            calls.resize_with(index + 1, ToolCallAccum::default);
        }

        let acc = &mut calls[index];
        if let Some(id) = tc.get("id").and_then(|x| x.as_str()) {
            if !id.is_empty() {
                acc.id = id.to_string();
            }
        }
        if let Some(func) = tc.get("function") {
            if let Some(name) = func.get("name").and_then(|x| x.as_str()) {
                if !name.is_empty() {
                    acc.name = name.to_string();
                }
            }
            if let Some(args) = func.get("arguments").and_then(|x| x.as_str()) {
                if !args.is_empty() {
                    acc.arguments.push_str(args);
                }
            }
        }
    }
}

fn build_assistant_tool_calls_message(tool_calls: &[ToolCallAccum]) -> Value {
    let tcs: Vec<Value> = tool_calls
        .iter()
        .enumerate()
        .map(|(i, tc)| {
            json!({
                "index": i,
                "id": if tc.id.is_empty() {
                    format!("call_{i}")
                } else {
                    tc.id.clone()
                },
                "type": "function",
                "function": {
                    "name": tc.name,
                    "arguments": tc.arguments,
                }
            })
        })
        .collect();
    json!({
        "role": "assistant",
        "content": null,
        "tool_calls": tcs,
    })
}

async fn post_completion_stream(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: &[Value],
    tools: &[Value],
) -> Result<reqwest::Response, String> {
    let url = format!("{}/chat/completions", cfg.base_url);
    let body = json!({
        "model": cfg.model,
        "stream": true,
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
        let text = response
            .text()
            .await
            .unwrap_or_else(|_| "(empty body)".into());
        return Err(format!("llm HTTP {status}: {text}"));
    }
    Ok(response)
}

fn parse_sse_data_json_line(line: &str) -> Option<Option<Value>> {
    let data = line.strip_prefix("data:")?.trim();
    if data == "[DONE]" {
        return Some(None);
    }
    serde_json::from_str::<Value>(data).ok().map(Some)
}

fn start_chat_message(
    out: &UnboundedSender<String>,
    assistant_name: &str,
    request_id: Option<&str>,
) -> (Uuid, Uuid) {
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

    (message_id, content_id)
}

fn finish_chat_message(
    out: &UnboundedSender<String>,
    message_id: Uuid,
    stopped: bool,
    request_id: Option<&str>,
) {
    let status = if stopped { "stop" } else { "complete" };
    let _ = out.send(envelope(
        "chat.message.updated",
        json!({
            "id": message_id.to_string(),
            "status": status,
        }),
        request_id,
    ));
}

#[allow(clippy::too_many_arguments)]
pub async fn harness_agent_run_streaming_tools(
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
        let (message_id, content_id) = start_chat_message(&out, assistant_name, request_id);

        let response = tokio::select! {
            _ = cancel.cancelled() => {
                finish_chat_message(&out, message_id, true, request_id);
                let _ = out.send(envelope(
                    "harness.agent.cancelled",
                    json!({ "tool_rounds_executed": tool_rounds_executed }),
                    request_id,
                ));
                return Ok(());
            }
            res = post_completion_stream(cfg, client, &messages, &tools) => res?,
        };

        let mut stream = response.bytes_stream();
        let mut buffer = String::new();
        let mut stopped = false;
        let mut tool_calls: Vec<ToolCallAccum> = vec![];
        let mut finish_reason: Option<String> = None;

        loop {
            tokio::select! {
                _ = cancel.cancelled() => {
                    stopped = true;
                    break;
                }
                next = stream.next() => {
                    let Some(chunk) = next else { break; };
                    let chunk = chunk.map_err(|e| format!("llm stream: {e}"))?;
                    let piece = std::str::from_utf8(&chunk).map_err(|_| "llm: invalid utf-8")?;
                    buffer.push_str(piece);

                    while let Some(pos) = buffer.find('\n') {
                        let raw_line = buffer[..pos].trim_end_matches('\r').to_string();
                        buffer.drain(..=pos);
                        let line = raw_line.trim();
                        if line.is_empty() {
                            continue;
                        }

                        let Some(parsed) = parse_sse_data_json_line(line) else {
                            continue;
                        };
                        let Some(v) = parsed else {
                            finish_reason = finish_reason.or(Some("done".to_string()));
                            break;
                        };

                        let choice0 = match v.get("choices").and_then(|c| c.as_array()).and_then(|a| a.first()) {
                            Some(c) => c,
                            None => continue,
                        };

                        if let Some(fr) = choice0.get("finish_reason").and_then(|x| x.as_str()) {
                            if !fr.is_empty() {
                                finish_reason = Some(fr.to_string());
                            }
                        }

                        let delta = match choice0.get("delta") {
                            Some(d) => d,
                            None => continue,
                        };

                        if let Some(content) = delta.get("content") {
                            if let Some(s) = content.as_str() {
                                if !s.is_empty() {
                                    let _ = out.send(envelope(
                                        "chat.content.updated",
                                        json!({
                                            "messageId": message_id.to_string(),
                                            "contentId": content_id.to_string(),
                                            "append": s,
                                        }),
                                        request_id,
                                    ));
                                }
                            }
                        }

                        if let Some(tcs) = delta.get("tool_calls").and_then(|x| x.as_array()) {
                            if !tcs.is_empty() {
                                apply_tool_call_deltas(&mut tool_calls, tcs);
                            }
                        }
                    }
                }
            }

            if finish_reason.as_deref() == Some("done") {
                break;
            }
        }

        finish_chat_message(&out, message_id, stopped, request_id);

        if stopped {
            let _ = out.send(envelope(
                "harness.agent.cancelled",
                json!({ "tool_rounds_executed": tool_rounds_executed }),
                request_id,
            ));
            return Ok(());
        }

        match finish_reason.as_deref() {
            Some("tool_calls") => {
                if tool_calls.is_empty() {
                    return Err("llm: finish_reason=tool_calls but no tool_calls deltas".into());
                }

                let assistant_msg = build_assistant_tool_calls_message(&tool_calls);
                messages.push(assistant_msg.clone());

                for (i, tc) in tool_calls.iter().enumerate() {
                    let call_id = if tc.id.is_empty() {
                        format!("call_{i}")
                    } else {
                        tc.id.clone()
                    };
                    let name = tc.name.trim();
                    let args_str = if tc.arguments.trim().is_empty() {
                        "{}"
                    } else {
                        tc.arguments.trim()
                    };
                    let args: Value = serde_json::from_str(args_str)
                        .unwrap_or_else(|_| json!({ "parse_error": true, "raw": args_str }));

                    let _ = out.send(envelope(
                        "harness.agent.tool_call",
                        json!({ "call_id": call_id, "name": name, "arguments": args }),
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

                    let content =
                        serde_json::to_string(&tool_result).unwrap_or_else(|_| "{}".into());
                    messages.push(json!({
                        "role": "tool",
                        "tool_call_id": call_id,
                        "content": content,
                    }));
                }

                tool_rounds_executed = tool_rounds_executed.saturating_add(1);
                continue;
            }
            Some("stop") | Some("done") | None => {
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
            Some(other) => {
                return Err(format!("llm: unexpected finish_reason={other}"));
            }
        }
    }

    Err(format!(
        "harness agent: exceeded {max_tool_rounds} tool rounds without a final assistant message"
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tool_call_deltas_accumulate_name_and_arguments() {
        let mut calls = vec![];
        apply_tool_call_deltas(
            &mut calls,
            &[json!({
                "index": 0,
                "id": "call_1",
                "type": "function",
                "function": { "name": "my_tool", "arguments": "{\"a\":" }
            })],
        );
        apply_tool_call_deltas(
            &mut calls,
            &[json!({
                "index": 0,
                "type": "function",
                "function": { "arguments": "1}" }
            })],
        );

        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].id, "call_1");
        assert_eq!(calls[0].name, "my_tool");
        assert_eq!(calls[0].arguments, "{\"a\":1}");

        let msg = build_assistant_tool_calls_message(&calls);
        assert_eq!(msg["role"].as_str(), Some("assistant"));
        assert!(msg["tool_calls"].as_array().is_some());
    }
}
