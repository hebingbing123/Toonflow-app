//! OpenAI-compatible speech synthesis (`POST /audio/speech`).

use serde_json::json;

use super::config::LlmConfig;

pub async fn audio_speech_bytes(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    input: &str,
    voice: &str,
    speed: f32,
    response_format: &str,
) -> Result<Vec<u8>, String> {
    let url = format!("{}/audio/speech", cfg.base_url);
    let body = json!({
        "model": cfg.model,
        "input": input,
        "voice": voice,
        "speed": speed,
        "response_format": response_format,
    });
    let response = client
        .post(&url)
        .header("Authorization", format!("Bearer {}", cfg.api_key))
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("speech request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        return Err(format!("speech HTTP {status}: {text}"));
    }
    response
        .bytes()
        .await
        .map(|bytes| bytes.to_vec())
        .map_err(|e| format!("speech body: {e}"))
}
