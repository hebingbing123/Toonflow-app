//! LLM 工具调用：`script_asset_extract_result` 与响应解析。

use serde_json::{json, Value};

use crate::llm::LlmConfig;

use super::schema::extract_tool_schema;
use super::types::ToolResultPayload;

pub(crate) async fn call_extract_tool(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    system: &str,
    user: &str,
) -> Result<ToolResultPayload, String> {
    let tools = vec![json!({
        "type": "function",
        "function": {
            "name": "script_asset_extract_result",
            "description": "Return extracted assets; call exactly once with arrays (may be empty only if truly no entities).",
            "parameters": extract_tool_schema(),
        }
    })];

    let body = json!({
        "model": cfg.model,
        "stream": false,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "tools": tools,
        "tool_choice": {"type": "function", "function": {"name": "script_asset_extract_result"}},
    });

    let url = format!("{}/chat/completions", cfg.base_url);
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

    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("llm json: {e}"))?;
    let msg = v
        .get("choices")
        .and_then(|c| c.as_array())
        .and_then(|a| a.first())
        .and_then(|c| c.get("message"))
        .ok_or_else(|| "llm: missing choices[0].message".to_string())?;

    let tcs = msg
        .get("tool_calls")
        .and_then(|x| x.as_array())
        .filter(|a| !a.is_empty())
        .ok_or_else(|| "llm: expected tool_calls".to_string())?;

    let tc = tcs
        .first()
        .ok_or_else(|| "llm: empty tool_calls".to_string())?;
    let func = tc
        .get("function")
        .ok_or_else(|| "llm: missing function".to_string())?;
    let name = func
        .get("name")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .trim();
    if name != "script_asset_extract_result" {
        return Err(format!("llm: unexpected tool {name}"));
    }
    let args_str = func
        .get("arguments")
        .and_then(|x| x.as_str())
        .unwrap_or("{}");
    serde_json::from_str::<ToolResultPayload>(args_str)
        .map_err(|e| format!("llm: bad tool arguments: {e}"))
}
