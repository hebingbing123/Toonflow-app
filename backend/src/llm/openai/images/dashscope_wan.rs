//! Alibaba DashScope 万相文生图（官方异步 API，非 OpenAI compatible-mode）。
//!
//! wanx2.1 / wan2.x T2I: `POST /api/v1/services/aigc/text2image/image-synthesis`
//! + `X-DashScope-Async: enable`, poll `GET /api/v1/tasks/{task_id}`.
//!
//! Docs: https://help.aliyun.com/zh/model-studio/text-to-image-v2-api-reference

use std::time::Duration;

use serde_json::{json, Value};

use super::super::config::LlmConfig;
use super::resolve::clip_prompt_chars;
use super::resolve::DALLE3_MAX_PROMPT_CHARS;

const IMAGE_SYNTHESIS_PATH: &str = "/api/v1/services/aigc/text2image/image-synthesis";
const MULTIMODAL_GENERATION_PATH: &str = "/api/v1/services/aigc/multimodal-generation/generation";

/// Catalog / request model ids for DashScope Wan image backends.
pub fn is_dashscope_wan_image_model(model: &str) -> bool {
    let lower = model.to_ascii_lowercase();
    lower.contains("wanx")
        || (lower.contains("wan2") && (lower.contains("t2i") || lower.contains("image")))
        || lower.starts_with("wan2.6")
}

fn uses_multimodal_generation(model: &str) -> bool {
    let lower = model.to_ascii_lowercase();
    lower.contains("wan2.6") && lower.contains("image")
}

/// Derive DashScope API root from configured `base_url` (strips `/compatible-mode/v1` suffix).
pub fn dashscope_api_root(base_url: &str) -> String {
    let mut root = base_url.trim().trim_end_matches('/').to_string();
    for suffix in ["/compatible-mode/v1", "/compatible-mode"] {
        if let Some(stripped) = root.strip_suffix(suffix) {
            root = stripped.to_string();
            break;
        }
    }
    if root.is_empty() {
        return "https://dashscope.aliyuncs.com".to_string();
    }
    root
}

/// Openflow `1024x1024` → DashScope `1024*1024`.
pub fn to_dashscope_size(size: &str) -> String {
    size.trim().replace(['×', 'x', 'X'], "*")
}

pub async fn dashscope_wan_images_generation_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
) -> Result<(String, Option<String>), String> {
    let prompt = clip_prompt_chars(prompt, DALLE3_MAX_PROMPT_CHARS);
    let root = dashscope_api_root(&cfg.base_url);
    if uses_multimodal_generation(model) {
        return multimodal_generation_sync(client, &root, &cfg.api_key, model, &prompt, size).await;
    }
    text2image_async_poll(client, &root, &cfg.api_key, model, &prompt, size).await
}

async fn text2image_async_poll(
    client: &reqwest::Client,
    root: &str,
    api_key: &str,
    model: &str,
    prompt: &str,
    size: &str,
) -> Result<(String, Option<String>), String> {
    let url = format!("{root}{IMAGE_SYNTHESIS_PATH}");
    let body = json!({
        "model": model,
        "input": { "prompt": prompt },
        "parameters": {
            "size": to_dashscope_size(size),
            "n": 1,
        }
    });

    let create = client
        .post(&url)
        .header("Authorization", format!("Bearer {api_key}"))
        .header("Content-Type", "application/json")
        .header("X-DashScope-Async", "enable")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("dashscope wan create: {e}"))?;
    if !create.status().is_success() {
        let status = create.status();
        let text = create.text().await.unwrap_or_default();
        return Err(format!("dashscope wan create HTTP {status}: {text}"));
    }
    let created: Value = create
        .json()
        .await
        .map_err(|e| format!("dashscope wan create json: {e}"))?;
    let task_id = created
        .pointer("/output/task_id")
        .and_then(|v| v.as_str())
        .ok_or_else(|| format!("dashscope wan: missing output.task_id in {created}"))?;

    poll_task_until_image(client, root, api_key, task_id).await
}

async fn multimodal_generation_sync(
    client: &reqwest::Client,
    root: &str,
    api_key: &str,
    model: &str,
    prompt: &str,
    size: &str,
) -> Result<(String, Option<String>), String> {
    let url = format!("{root}{MULTIMODAL_GENERATION_PATH}");
    let body = json!({
        "model": model,
        "input": {
            "messages": [{
                "role": "user",
                "content": [{ "text": prompt }]
            }]
        },
        "parameters": {
            "size": to_dashscope_size(size),
        }
    });
    let resp = client
        .post(&url)
        .header("Authorization", format!("Bearer {api_key}"))
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("dashscope multimodal: {e}"))?;
    if !resp.status().is_success() {
        let status = resp.status();
        let text = resp.text().await.unwrap_or_default();
        return Err(format!("dashscope multimodal HTTP {status}: {text}"));
    }
    let v: Value = resp
        .json()
        .await
        .map_err(|e| format!("dashscope multimodal json: {e}"))?;
    extract_image_url(&v).map(|url| (url, None))
}

async fn poll_task_until_image(
    client: &reqwest::Client,
    root: &str,
    api_key: &str,
    task_id: &str,
) -> Result<(String, Option<String>), String> {
    let url = format!("{root}/api/v1/tasks/{task_id}");
    for _ in 0..90 {
        let resp = client
            .get(&url)
            .header("Authorization", format!("Bearer {api_key}"))
            .send()
            .await
            .map_err(|e| format!("dashscope task poll: {e}"))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            return Err(format!("dashscope task poll HTTP {status}: {text}"));
        }
        let v: Value = resp
            .json()
            .await
            .map_err(|e| format!("dashscope task json: {e}"))?;
        let task_status = v
            .pointer("/output/task_status")
            .and_then(|s| s.as_str())
            .unwrap_or("");
        match task_status {
            "SUCCEEDED" => {
                return extract_image_url(&v).map(|url| (url, None));
            }
            "FAILED" => {
                let msg = v
                    .pointer("/output/message")
                    .and_then(|m| m.as_str())
                    .unwrap_or("dashscope wan task failed");
                return Err(msg.to_string());
            }
            _ => tokio::time::sleep(Duration::from_secs(1)).await,
        }
    }
    Err("dashscope wan task poll timeout".into())
}

fn extract_image_url(v: &Value) -> Result<String, String> {
    if let Some(url) = v.pointer("/output/results/0/url").and_then(|x| x.as_str()) {
        return Ok(url.to_string());
    }
    if let Some(arr) = v.pointer("/output/choices").and_then(|c| c.as_array()) {
        for choice in arr {
            if let Some(content) = choice
                .pointer("/message/content")
                .and_then(|c| c.as_array())
            {
                for item in content {
                    if let Some(url) = item.get("image").and_then(|i| i.as_str()) {
                        return Ok(url.to_string());
                    }
                }
            }
        }
    }
    Err(format!("dashscope wan: no image url in {v}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wan_model_detection() {
        assert!(is_dashscope_wan_image_model("wanx2.1-t2i-turbo"));
        assert!(is_dashscope_wan_image_model("wan2.6-image"));
        assert!(!is_dashscope_wan_image_model("qwen-plus"));
    }

    #[test]
    fn size_converts_x_to_star() {
        assert_eq!(to_dashscope_size("1024x1024"), "1024*1024");
    }

    #[test]
    fn root_from_compatible_mode_base() {
        let root = dashscope_api_root("https://dashscope.aliyuncs.com/compatible-mode/v1");
        assert_eq!(root, "https://dashscope.aliyuncs.com");
        let mock = dashscope_api_root("http://127.0.0.1:45678/compatible-mode/v1");
        assert_eq!(mock, "http://127.0.0.1:45678");
    }
}
