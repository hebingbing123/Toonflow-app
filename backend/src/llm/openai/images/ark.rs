//! Volcengine Ark / Doubao Seedream — OpenAI-shaped `POST /images/generations`.

use serde_json::json;

use super::super::config::LlmConfig;
use super::response::parse_images_response;

pub async fn ark_images_generation_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
) -> Result<(String, Option<String>), String> {
    let url = format!("{}/images/generations", cfg.base_url.trim_end_matches('/'));
    let body = json!({
        "model": model,
        "prompt": prompt,
        "n": 1,
        "size": size,
        "response_format": "url",
    });
    let response = client
        .post(&url)
        .header("Authorization", format!("Bearer {}", cfg.api_key))
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("ark images request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response
            .text()
            .await
            .unwrap_or_else(|_| "(empty body)".into());
        return Err(format!("ark images HTTP {status}: {text}"));
    }
    let v = response
        .json()
        .await
        .map_err(|e| format!("ark images json: {e}"))?;
    parse_images_response(&v)
}
