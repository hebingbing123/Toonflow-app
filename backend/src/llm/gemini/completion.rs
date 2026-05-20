//! Google Gemini native `generateContent` API.

use serde_json::{json, Value};

use crate::llm::openai::chat::completion::ChatCompletionResult;
use crate::llm::openai::chat::parse::TokenUsage;
use crate::llm::LlmConfig;

fn gemini_root(cfg: &LlmConfig) -> String {
    let trimmed = cfg.base_url.trim().trim_end_matches('/');
    if trimmed.contains("generativelanguage.googleapis.com") {
        return trimmed
            .trim_end_matches("/openai")
            .trim_end_matches("/v1beta/openai")
            .to_string();
    }
    "https://generativelanguage.googleapis.com/v1beta".to_string()
}

fn openai_messages_to_gemini(messages: &[Value]) -> (Option<Value>, Vec<Value>) {
    let mut system_parts = Vec::new();
    let mut contents = Vec::new();
    for msg in messages {
        let role = msg.get("role").and_then(|r| r.as_str()).unwrap_or("user");
        let text = msg
            .get("content")
            .and_then(|c| c.as_str())
            .map(String::from)
            .unwrap_or_else(|| {
                msg.get("content")
                    .map(|c| c.to_string())
                    .unwrap_or_default()
            });
        if role == "system" {
            system_parts.push(text);
            continue;
        }
        let gemini_role = if role == "assistant" { "model" } else { "user" };
        contents.push(json!({
            "role": gemini_role,
            "parts": [{"text": text}],
        }));
    }
    let system_instruction = if system_parts.is_empty() {
        None
    } else {
        Some(json!({"parts": [{"text": system_parts.join("\n\n")}]}))
    };
    (system_instruction, contents)
}

pub async fn gemini_chat_completion_with_usage(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: Vec<Value>,
) -> Result<ChatCompletionResult, String> {
    let root = gemini_root(cfg);
    let model = cfg.model.trim();
    let url = format!("{root}/models/{model}:generateContent");
    let (system_instruction, contents) = openai_messages_to_gemini(&messages);
    let mut body = json!({"contents": contents});
    if let Some(sys) = system_instruction {
        body["systemInstruction"] = sys;
    }
    let response = client
        .post(&url)
        .query(&[("key", cfg.api_key.as_str())])
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("gemini request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        return Err(format!("gemini HTTP {status}: {text}"));
    }
    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("gemini json: {e}"))?;
    let parts = v
        .pointer("/candidates/0/content/parts")
        .and_then(|p| p.as_array())
        .ok_or_else(|| "gemini: missing candidates".to_string())?;
    let mut text_out = String::new();
    for part in parts {
        if let Some(t) = part.get("text").and_then(|x| x.as_str()) {
            text_out.push_str(t);
        }
    }
    if text_out.trim().is_empty() {
        return Err("gemini: empty text response".into());
    }
    let usage_meta = v.get("usageMetadata");
    let usage = usage_meta.map(|u| TokenUsage {
        prompt_tokens: u
            .get("promptTokenCount")
            .and_then(|x| x.as_i64())
            .unwrap_or(0),
        completion_tokens: u
            .get("candidatesTokenCount")
            .and_then(|x| x.as_i64())
            .unwrap_or(0),
        total_tokens: u
            .get("totalTokenCount")
            .and_then(|x| x.as_i64())
            .unwrap_or(0),
    });
    Ok(ChatCompletionResult {
        content: text_out,
        usage,
        model: Some(model.to_string()),
    })
}
