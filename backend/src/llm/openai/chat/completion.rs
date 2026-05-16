use serde_json::{json, Value};

use super::super::config::LlmConfig;
use super::parse::{parse_assistant_content, parse_usage, TokenUsage};

/// Result of a non-streaming chat completion.
#[derive(Debug, Clone)]
pub struct ChatCompletionResult {
    pub content: String,
    pub usage: Option<TokenUsage>,
    pub model: Option<String>,
}

/// Non-streaming chat completion; returns trimmed assistant text with optional usage.
pub async fn chat_completion_with_usage(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: Vec<Value>,
) -> Result<ChatCompletionResult, String> {
    let url = format!("{}/chat/completions", cfg.base_url);
    let body = json!({
        "model": cfg.model,
        "stream": false,
        "messages": messages,
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
    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("llm json: {e}"))?;
    let content = parse_assistant_content(&v)?;
    let usage = parse_usage(&v);
    let model = v.get("model").and_then(|m| m.as_str()).map(String::from);
    Ok(ChatCompletionResult {
        content,
        usage,
        model,
    })
}

/// Non-streaming chat completion; returns trimmed assistant text (no tools).
/// Backward-compatible wrapper that discards usage.
pub async fn chat_completion_assistant_text(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: Vec<Value>,
) -> Result<String, String> {
    chat_completion_with_usage(cfg, client, messages)
        .await
        .map(|r| r.content)
}
