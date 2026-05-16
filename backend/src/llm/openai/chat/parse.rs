use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Token usage returned by OpenAI-compatible APIs.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TokenUsage {
    pub prompt_tokens: i64,
    pub completion_tokens: i64,
    pub total_tokens: i64,
}

/// Extract `usage` from a non-streaming chat completion response.
pub(crate) fn parse_usage(v: &Value) -> Option<TokenUsage> {
    let usage = v.get("usage")?;
    Some(TokenUsage {
        prompt_tokens: usage.get("prompt_tokens")?.as_i64()?,
        completion_tokens: usage.get("completion_tokens")?.as_i64()?,
        total_tokens: usage.get("total_tokens")?.as_i64()?,
    })
}

/// Parses `choices[0].message.content` from a non-streaming chat completion JSON body.
pub(crate) fn parse_assistant_content(v: &Value) -> Result<String, String> {
    let choice0 = v
        .get("choices")
        .and_then(|c| c.as_array())
        .and_then(|a| a.first())
        .ok_or_else(|| "missing choices[0]".to_string())?;
    let content = choice0
        .get("message")
        .and_then(|m| m.get("content"))
        .ok_or_else(|| "missing message.content".to_string())?;
    match content {
        Value::String(s) => {
            let t = s.trim().to_owned();
            if t.is_empty() {
                Err("empty assistant content".into())
            } else {
                Ok(t)
            }
        }
        Value::Array(parts) => {
            let mut out = String::new();
            for p in parts {
                if p.get("type").and_then(|t| t.as_str()) == Some("text") {
                    if let Some(t) = p.get("text").and_then(|x| x.as_str()) {
                        out.push_str(t);
                    }
                }
            }
            let t = out.trim().to_owned();
            if t.is_empty() {
                Err("empty text content in message.parts".into())
            } else {
                Ok(t)
            }
        }
        Value::Null => Err("message.content is null".into()),
        _ => Err(format!("unexpected message.content type: {content}")),
    }
}

/// Returns `None` for ignorable lines; `Some(\"\")` for `[DONE]`; `Some(text)` for token delta.
pub(crate) fn parse_sse_data_line(line: &str) -> Option<String> {
    let data = line.strip_prefix("data:")?.trim();
    if data == "[DONE]" {
        return Some(String::new());
    }
    let v: Value = serde_json::from_str(data).ok()?;
    let choice0 = v.get("choices")?.as_array()?.first()?;
    let delta = choice0.get("delta")?;
    let content = delta.get("content")?;
    match content {
        Value::String(s) => Some(s.clone()),
        Value::Null => Some(String::new()),
        _ => Some(content.to_string()),
    }
}
