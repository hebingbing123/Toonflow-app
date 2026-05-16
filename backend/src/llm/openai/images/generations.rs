use serde_json::{json, Value};

use super::super::config::LlmConfig;
use super::resolve::{clip_prompt_chars, DALLE3_MAX_PROMPT_CHARS};
use super::response::parse_images_response;

/// OpenAI-compatible **`POST /v1/images/generations`** with **`response_format: url`**.
/// Returns **(image_url, revised_prompt)** — revised prompt is set for DALL-E 3.
pub async fn images_generation_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
) -> Result<(String, Option<String>), String> {
    let prompt = clip_prompt_chars(prompt, DALLE3_MAX_PROMPT_CHARS);
    let url = format!("{}/images/generations", cfg.base_url);
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
        .map_err(|e| format!("images request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response
            .text()
            .await
            .unwrap_or_else(|_| "(empty body)".into());
        return Err(format!("images HTTP {status}: {text}"));
    }
    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("images json: {e}"))?;
    parse_images_response(&v)
}
