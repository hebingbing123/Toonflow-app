use reqwest::multipart::{Form, Part};
use serde_json::Value;

use super::super::config::LlmConfig;
use super::reference::parse_reference_image_upload;
use super::resolve::{clip_prompt_chars, DALLE3_MAX_PROMPT_CHARS};
use super::response::parse_images_response;

/// OpenAI-compatible **`POST /v1/images/edits`** with one reference image.
/// Returns **(image_url, revised_prompt)**.
pub async fn images_edit_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
    image_base64: &str,
) -> Result<(String, Option<String>), String> {
    let prompt = clip_prompt_chars(prompt, DALLE3_MAX_PROMPT_CHARS);
    let upload = parse_reference_image_upload(image_base64)?;

    let image_part = Part::bytes(upload.bytes)
        .mime_str(upload.mime)
        .map_err(|e| format!("invalid image mime: {e}"))?
        .file_name(upload.file_name.to_string());
    let form = Form::new()
        .text("model", model.to_string())
        .text("prompt", prompt)
        .text("n", "1".to_string())
        .text("size", size.to_string())
        .text("response_format", "url".to_string())
        .part("image", image_part);

    let url = format!("{}/images/edits", cfg.base_url);
    let response = client
        .post(&url)
        .header("Authorization", format!("Bearer {}", cfg.api_key))
        .multipart(form)
        .send()
        .await
        .map_err(|e| format!("images edit request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response
            .text()
            .await
            .unwrap_or_else(|_| "(empty body)".into());
        return Err(format!("images edits HTTP {status}: {text}"));
    }
    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("images edits json: {e}"))?;
    parse_images_response(&v)
}
