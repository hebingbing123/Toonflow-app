use base64::Engine;
use reqwest::multipart::{Form, Part};
use serde_json::{json, Value};

use super::config::LlmConfig;

/// DALL-E 3 **`prompt`** cap (characters).
const DALLE3_MAX_PROMPT_CHARS: usize = 4_000;
const MAX_REFERENCE_IMAGE_BYTES: usize = 15 * 1024 * 1024;

fn clip_prompt_chars(s: &str, max_chars: usize) -> String {
    let n = s.chars().count();
    if n <= max_chars {
        return s.to_string();
    }
    s.chars().take(max_chars).collect()
}

/// Picks an OpenAI **`images/generations`** model id from the vendor catalog string (e.g. **`1:dall-e-3`**) or **`TOONFLOW_IMAGE_MODEL`**, default **`dall-e-3`**.
pub fn resolve_openai_image_model(request_model: &str) -> String {
    let lower = request_model.to_lowercase();
    if lower.contains("dall-e-2") || lower.contains("dalle-2") {
        return "dall-e-2".into();
    }
    if lower.contains("dall-e-3") || lower.contains("dalle-3") {
        return "dall-e-3".into();
    }
    std::env::var("TOONFLOW_IMAGE_MODEL")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "dall-e-3".into())
}

/// Maps Electron-era **`resolution`** (e.g. **`1024x1024`**) to an OpenAI **`size`** for the chosen model.
pub fn resolve_openai_image_size(model: &str, resolution: &str) -> &'static str {
    let m = model.to_lowercase();
    let r = resolution.to_lowercase().replace('×', "x").replace(' ', "");
    if m.contains("dall-e-3") || m.contains("dalle-3") {
        return match r.as_str() {
            "1792x1024" => "1792x1024",
            "1024x1792" => "1024x1792",
            _ => "1024x1024",
        };
    }
    match r.as_str() {
        "256x256" => "256x256",
        "512x512" => "512x512",
        "1024x1024" => "1024x1024",
        _ => "1024x1024",
    }
}

fn parse_images_response(v: &Value) -> Result<(String, Option<String>), String> {
    let data0 = v
        .get("data")
        .and_then(|d| d.as_array())
        .and_then(|a| a.first())
        .ok_or_else(|| "missing data[0]".to_string())?;
    let url_str = data0
        .get("url")
        .and_then(|u| u.as_str())
        .ok_or_else(|| "missing data[0].url".to_string())?;
    let revised = data0
        .get("revised_prompt")
        .and_then(|x| x.as_str())
        .map(str::to_string);
    Ok((url_str.to_string(), revised))
}

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

#[derive(Debug)]
pub(crate) struct ReferenceImageUpload {
    pub(crate) bytes: Vec<u8>,
    pub(crate) mime: &'static str,
    pub(crate) file_name: &'static str,
}

pub(crate) fn parse_reference_image_upload(
    image_base64: &str,
) -> Result<ReferenceImageUpload, String> {
    let trimmed = image_base64.trim();
    if trimmed.is_empty() {
        return Err("reference image base64 is empty".into());
    }

    let (mime, file_name, b64) = match trimmed.strip_prefix("data:") {
        Some(rest) => {
            let (meta, b64) = rest
                .split_once(";base64,")
                .ok_or_else(|| "reference image data URI must be base64".to_string())?;
            let (mime, file_name) = match meta.trim().to_ascii_lowercase().as_str() {
                "image/png" => ("image/png", "reference.png"),
                "image/jpeg" | "image/jpg" => ("image/jpeg", "reference.jpg"),
                "image/webp" => ("image/webp", "reference.webp"),
                other => return Err(format!("unsupported reference image mime: {other}")),
            };
            (mime, file_name, b64.trim())
        }
        None => ("image/jpeg", "reference.jpg", trimmed),
    };

    let bytes = base64::engine::general_purpose::STANDARD
        .decode(b64.as_bytes())
        .map_err(|_| "reference image is not valid base64".to_string())?;
    if bytes.is_empty() {
        return Err("reference image decodes to empty bytes".into());
    }
    if bytes.len() > MAX_REFERENCE_IMAGE_BYTES {
        return Err(format!(
            "reference image exceeds max decoded size ({MAX_REFERENCE_IMAGE_BYTES} bytes)"
        ));
    }

    Ok(ReferenceImageUpload {
        bytes,
        mime,
        file_name,
    })
}

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

/// Uses **`images/edits`** when a reference image is provided; otherwise **`images/generations`**.
pub async fn images_generation_or_edit_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
    image_base64: Option<&str>,
) -> Result<(String, Option<String>), String> {
    let Some(reference) = image_base64.map(str::trim).filter(|s| !s.is_empty()) else {
        return images_generation_url(cfg, client, model, prompt, size).await;
    };
    images_edit_url(cfg, client, model, prompt, size, reference).await
}
