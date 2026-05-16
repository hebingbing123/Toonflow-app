//! 非流式 Chat Completions HTTP 调用。

use serde_json::{json, Value};

use crate::llm::LlmConfig;

pub(super) async fn post_completion(
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
