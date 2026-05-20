//! Google Imagen via Generative Language API `predict`.

use serde_json::json;

use super::super::config::LlmConfig;

fn gemini_root(cfg: &LlmConfig) -> String {
    let trimmed = cfg.base_url.trim().trim_end_matches('/');
    if trimmed.contains("generativelanguage.googleapis.com") {
        return trimmed
            .trim_end_matches("/openai")
            .trim_end_matches("/v1beta/openai")
            .to_string();
    }
    if !trimmed.is_empty() {
        return trimmed.to_string();
    }
    "https://generativelanguage.googleapis.com/v1beta".to_string()
}

pub async fn gemini_imagen_generation_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    _size: &str,
) -> Result<(String, Option<String>), String> {
    let root = gemini_root(cfg);
    let url = format!("{root}/models/{model}:predict");
    let body = json!({
        "instances": [{"prompt": prompt}],
        "parameters": {
            "sampleCount": 1,
        }
    });
    let response = client
        .post(&url)
        .query(&[("key", cfg.api_key.as_str())])
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("imagen request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response
            .text()
            .await
            .unwrap_or_else(|_| "(empty body)".into());
        return Err(format!("imagen HTTP {status}: {text}"));
    }
    let v = response
        .json::<serde_json::Value>()
        .await
        .map_err(|e| format!("imagen json: {e}"))?;

    if let Some(url) = v
        .pointer("/generatedImages/0/imageUri")
        .and_then(|x| x.as_str())
    {
        return Ok((url.to_string(), None));
    }
    if let Some(b64) = v
        .pointer("/predictions/0/bytesBase64Encoded")
        .and_then(|x| x.as_str())
    {
        return Ok((format!("data:image/png;base64,{b64}"), None));
    }
    Err("imagen: missing image URL in response".into())
}
