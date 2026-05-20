//! Anthropic Messages API (`POST /v1/messages`).

use serde_json::{json, Value};

use crate::llm::openai::chat::completion::ChatCompletionResult;
use crate::llm::openai::chat::parse::TokenUsage;
use crate::llm::LlmConfig;

fn anthropic_base_url(cfg: &LlmConfig) -> String {
    let trimmed = cfg.base_url.trim().trim_end_matches('/');
    if trimmed.is_empty() || trimmed.contains("api.openai.com") {
        return "https://api.anthropic.com/v1".to_string();
    }
    if trimmed.ends_with("/v1") {
        return trimmed.to_string();
    }
    format!("{trimmed}/v1")
}

fn openai_messages_to_anthropic(messages: &[Value]) -> (Option<String>, Vec<Value>) {
    let mut system_parts = Vec::new();
    let mut out = Vec::new();
    for msg in messages {
        let role = msg.get("role").and_then(|r| r.as_str()).unwrap_or("user");
        let content = msg
            .get("content")
            .cloned()
            .unwrap_or(Value::String(String::new()));
        if role == "system" {
            if let Some(s) = content.as_str() {
                system_parts.push(s.to_string());
            } else {
                system_parts.push(content.to_string());
            }
            continue;
        }
        let anthropic_role = if role == "assistant" {
            "assistant"
        } else {
            "user"
        };
        let block = if content.is_string() {
            json!({"type": "text", "text": content})
        } else {
            json!({"type": "text", "text": content.to_string()})
        };
        out.push(json!({
            "role": anthropic_role,
            "content": [block],
        }));
    }
    let system = if system_parts.is_empty() {
        None
    } else {
        Some(system_parts.join("\n\n"))
    };
    (system, out)
}

fn parse_anthropic_content(v: &Value) -> Result<String, String> {
    let content = v
        .get("content")
        .and_then(|c| c.as_array())
        .ok_or_else(|| "anthropic: missing content array".to_string())?;
    let mut parts = Vec::new();
    for block in content {
        if block.get("type").and_then(|t| t.as_str()) == Some("text") {
            if let Some(t) = block.get("text").and_then(|x| x.as_str()) {
                parts.push(t.to_string());
            }
        }
    }
    if parts.is_empty() {
        return Err("anthropic: empty assistant content".into());
    }
    Ok(parts.join("\n"))
}

pub async fn anthropic_chat_completion_with_usage(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: Vec<Value>,
) -> Result<ChatCompletionResult, String> {
    let url = format!("{}/messages", anthropic_base_url(cfg));
    let (system, anthropic_messages) = openai_messages_to_anthropic(&messages);
    let mut body = json!({
        "model": cfg.model,
        "max_tokens": 1024,
        "messages": anthropic_messages,
    });
    if let Some(sys) = system {
        body["system"] = json!(sys);
    }
    let response = client
        .post(&url)
        .header("x-api-key", &cfg.api_key)
        .header("anthropic-version", "2023-06-01")
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("anthropic request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        return Err(format!("anthropic HTTP {status}: {text}"));
    }
    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("anthropic json: {e}"))?;
    let content = parse_anthropic_content(&v)?;
    let usage = v.get("usage").map(|u| TokenUsage {
        prompt_tokens: u.get("input_tokens").and_then(|x| x.as_i64()).unwrap_or(0),
        completion_tokens: u.get("output_tokens").and_then(|x| x.as_i64()).unwrap_or(0),
        total_tokens: 0,
    });
    let usage = usage.map(|mut u| {
        u.total_tokens = u.prompt_tokens.saturating_add(u.completion_tokens);
        u
    });
    Ok(ChatCompletionResult {
        content,
        usage,
        model: v.get("model").and_then(|m| m.as_str()).map(String::from),
    })
}
