//! LLM tool schema, response parsing, and filtering of model output.

use serde::Deserialize;
use serde_json::{json, Value};

use crate::llm::LlmConfig;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct ToolResultPayload {
    #[serde(default)]
    pub(crate) new_assets: Vec<NewAssetItem>,
    #[serde(default, alias = "existingAssetRefs")]
    pub(crate) existing_asset_refs: Vec<ExistingRefItem>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct NewAssetItem {
    pub(crate) name: String,
    pub(crate) desc: String,
    #[serde(rename = "type")]
    pub(crate) asset_type: String,
    #[serde(default, alias = "scriptIds", alias = "scriptLegacyIds")]
    pub(crate) script_legacy_ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ExistingRefItem {
    pub(crate) name: String,
    #[serde(default, alias = "scriptIds", alias = "scriptLegacyIds")]
    pub(crate) script_legacy_ids: Vec<i32>,
}

pub(crate) struct NewAssetItemFiltered {
    pub(crate) name: String,
    pub(crate) desc: String,
    pub(crate) asset_type: String,
    pub(crate) script_legacy_ids: Vec<i32>,
}

pub(crate) struct ExistingRefItemFiltered {
    pub(crate) name: String,
    pub(crate) script_legacy_ids: Vec<i32>,
}

pub(crate) fn filter_tool_new_assets(
    items: Vec<NewAssetItem>,
    valid: &std::collections::HashSet<i32>,
) -> Vec<NewAssetItemFiltered> {
    let mut out = Vec::new();
    let mut seen_name: std::collections::HashSet<String> = std::collections::HashSet::new();
    for mut it in items {
        let t = it.asset_type.trim().to_lowercase();
        if t != "role" && t != "tool" && t != "scene" {
            continue;
        }
        let name = it.name.trim().to_string();
        if name.is_empty() || !seen_name.insert(name.clone()) {
            continue;
        }
        it.script_legacy_ids.retain(|id| valid.contains(id));
        if it.script_legacy_ids.is_empty() {
            continue;
        }
        out.push(NewAssetItemFiltered {
            name,
            desc: it.desc,
            asset_type: t,
            script_legacy_ids: it.script_legacy_ids,
        });
    }
    out
}

pub(crate) fn filter_tool_existing(
    items: Vec<ExistingRefItem>,
    valid: &std::collections::HashSet<i32>,
) -> Vec<ExistingRefItemFiltered> {
    let mut out = Vec::new();
    for mut it in items {
        let name = it.name.trim().to_string();
        if name.is_empty() {
            continue;
        }
        it.script_legacy_ids.retain(|id| valid.contains(id));
        if it.script_legacy_ids.is_empty() {
            continue;
        }
        out.push(ExistingRefItemFiltered {
            name,
            script_legacy_ids: it.script_legacy_ids,
        });
    }
    out
}

fn extract_tool_schema() -> Value {
    json!({
        "type": "object",
        "required": ["new_assets", "existing_asset_refs"],
        "properties": {
            "new_assets": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["name", "desc", "type", "script_legacy_ids"],
                    "properties": {
                        "name": { "type": "string" },
                        "desc": { "type": "string" },
                        "type": { "type": "string", "enum": ["role", "tool", "scene"] },
                        "script_legacy_ids": {
                            "type": "array",
                            "items": { "type": "integer" }
                        }
                    },
                    "additionalProperties": false
                }
            },
            "existing_asset_refs": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["name", "script_legacy_ids"],
                    "properties": {
                        "name": { "type": "string" },
                        "script_legacy_ids": {
                            "type": "array",
                            "items": { "type": "integer" }
                        }
                    },
                    "additionalProperties": false
                }
            }
        },
        "additionalProperties": false
    })
}

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filter_new_drops_bad_type() {
        let valid: std::collections::HashSet<i32> = [1].into_iter().collect();
        let out = filter_tool_new_assets(
            vec![NewAssetItem {
                name: "A".into(),
                desc: "d".into(),
                asset_type: "wizard".into(),
                script_legacy_ids: vec![1],
            }],
            &valid,
        );
        assert!(out.is_empty());
    }
}
