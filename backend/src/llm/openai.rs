use base64::Engine;
use futures_util::StreamExt;
use reqwest::multipart::{Form, Part};
use serde_json::{json, Value};
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use super::envelope::envelope;

#[derive(Clone)]
pub struct LlmConfig {
    pub api_key: String,
    pub base_url: String,
    pub model: String,
}

impl LlmConfig {
    pub fn from_env() -> Option<Self> {
        let api_key = std::env::var("OPENAI_API_KEY")
            .or_else(|_| std::env::var("LLM_API_KEY"))
            .ok()
            .filter(|s| !s.is_empty())?;
        let base_url = std::env::var("OPENAI_BASE_URL")
            .unwrap_or_else(|_| "https://api.openai.com/v1".to_string());
        let base_url = base_url.trim_end_matches('/').to_string();
        let model = std::env::var("LLM_MODEL").unwrap_or_else(|_| "gpt-4o-mini".to_string());
        Some(Self {
            api_key,
            base_url,
            model,
        })
    }
}

/// Parses `choices[0].message.content` from a non-streaming chat completion JSON body.
fn parse_assistant_content(v: &Value) -> Result<String, String> {
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

/// Non-streaming chat completion; returns trimmed assistant text (no tools).
pub async fn chat_completion_assistant_text(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: Vec<Value>,
) -> Result<String, String> {
    let url = format!("{}/chat/completions", cfg.base_url);
    let body = json!({
        "model": cfg.model,
        "stream": false,
        "messages": messages,
    });
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
        let text = response
            .text()
            .await
            .unwrap_or_else(|_| "(empty body)".into());
        return Err(format!("llm HTTP {status}: {text}"));
    }
    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("llm json: {e}"))?;
    parse_assistant_content(&v)
}

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

/// Picks an OpenAI **`images/generations`** model id from the legacy catalog string (e.g. **`1:dall-e-3`**) or **`TOONFLOW_IMAGE_MODEL`**, default **`dall-e-3`**.
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

/// Maps legacy **`resolution`** (e.g. **`1024x1024`**) to an OpenAI **`size`** for the chosen model.
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

#[derive(Debug)]
struct ReferenceImageUpload {
    bytes: Vec<u8>,
    mime: &'static str,
    file_name: &'static str,
}

fn parse_reference_image_upload(image_base64: &str) -> Result<ReferenceImageUpload, String> {
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

/// Stream one assistant reply; emits `chat.message.*` / `chat.content.*` per `docs/websocket-events.md`.
pub async fn stream_chat_turn(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    user_message: &str,
    assistant_name: &str,
    cancel: CancellationToken,
    out: UnboundedSender<String>,
    request_id: Option<&str>,
) -> Result<(), String> {
    let message_id = Uuid::new_v4();
    let content_id = Uuid::new_v4();

    let _ = out.send(envelope(
        "chat.message.created",
        json!({
            "id": message_id.to_string(),
            "role": "assistant",
            "name": assistant_name,
            "status": "streaming",
            "datetime": chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
            "content": [],
        }),
        request_id,
    ));

    let _ = out.send(envelope(
        "chat.content.added",
        json!({
            "messageId": message_id.to_string(),
            "content": {
                "type": "text",
                "id": content_id.to_string(),
                "data": "",
                "status": "pending",
            }
        }),
        request_id,
    ));

    let url = format!("{}/chat/completions", cfg.base_url);
    let body = json!({
        "model": cfg.model,
        "stream": true,
        "messages": [{ "role": "user", "content": user_message }],
    });

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
        let text = response
            .text()
            .await
            .unwrap_or_else(|_| "(empty body)".into());
        return Err(format!("llm HTTP {status}: {text}"));
    }

    let mut stream = response.bytes_stream();
    let mut buffer = String::new();
    let mut stopped = false;

    loop {
        tokio::select! {
            _ = cancel.cancelled() => {
                stopped = true;
                break;
            }
            next = stream.next() => {
                let Some(chunk) = next else { break; };
                let chunk = chunk.map_err(|e| format!("llm stream: {e}"))?;
                let piece = std::str::from_utf8(&chunk).map_err(|_| "llm: invalid utf-8")?;
                buffer.push_str(piece);

                while let Some(pos) = buffer.find('\n') {
                    let raw_line = buffer[..pos].trim_end_matches('\r').to_string();
                    buffer.drain(..=pos);
                    let line = raw_line.trim();
                    if line.is_empty() {
                        continue;
                    }
                    if let Some(delta) = parse_sse_data_line(line) {
                        if delta.is_empty() {
                            continue;
                        }
                        let _ = out.send(envelope(
                            "chat.content.updated",
                            json!({
                                "messageId": message_id.to_string(),
                                "contentId": content_id.to_string(),
                                "append": delta,
                            }),
                            request_id,
                        ));
                    }
                }
            }
        }
    }

    let status = if stopped { "stop" } else { "complete" };
    let _ = out.send(envelope(
        "chat.message.updated",
        json!({
            "id": message_id.to_string(),
            "status": status,
        }),
        request_id,
    ));

    Ok(())
}

/// Returns `None` for ignorable lines; `Some("")` for `[DONE]`; `Some(text)` for token delta.
fn parse_sse_data_line(line: &str) -> Option<String> {
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

#[cfg(test)]
mod tests {
    use std::sync::{Arc, Mutex};

    use super::*;
    use axum::{body::Bytes, extract::State, http::HeaderMap, routing::post, Json, Router};

    #[derive(Clone, Default)]
    struct TestImagesApiState {
        generation_hits: usize,
        edits_hits: usize,
        last_edit_content_type: Option<String>,
    }

    async fn test_images_generation(
        State(state): State<Arc<Mutex<TestImagesApiState>>>,
    ) -> Json<Value> {
        state.lock().expect("lock").generation_hits += 1;
        Json(json!({"data":[{"url":"https://example.test/generation.png"}]}))
    }

    async fn test_images_edits(
        State(state): State<Arc<Mutex<TestImagesApiState>>>,
        headers: HeaderMap,
        _body: Bytes,
    ) -> Json<Value> {
        let mut guard = state.lock().expect("lock");
        guard.edits_hits += 1;
        guard.last_edit_content_type = headers
            .get("content-type")
            .and_then(|v| v.to_str().ok())
            .map(str::to_string);
        Json(json!({"data":[{"url":"https://example.test/edit.png"}]}))
    }

    async fn spawn_test_images_api() -> (
        String,
        Arc<Mutex<TestImagesApiState>>,
        tokio::sync::oneshot::Sender<()>,
    ) {
        let state = Arc::new(Mutex::new(TestImagesApiState::default()));
        let app = Router::new()
            .route("/v1/images/generations", post(test_images_generation))
            .route("/v1/images/edits", post(test_images_edits))
            .with_state(state.clone());
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
            .await
            .expect("bind");
        let addr = listener.local_addr().expect("local addr");
        let (tx, rx) = tokio::sync::oneshot::channel::<()>();
        tokio::spawn(async move {
            let server = axum::serve(listener, app).with_graceful_shutdown(async {
                let _ = rx.await;
            });
            server.await.expect("serve");
        });
        (format!("http://{addr}/v1"), state, tx)
    }

    #[test]
    fn sse_parses_delta() {
        let line = r#"data: {"choices":[{"delta":{"content":"Hi"}}]}"#;
        assert_eq!(parse_sse_data_line(line).as_deref(), Some("Hi"));
    }

    #[test]
    fn sse_done() {
        let line = "data: [DONE]";
        assert_eq!(parse_sse_data_line(line).as_deref(), Some(""));
    }

    #[test]
    fn parses_assistant_string_content() {
        let v = json!({"choices":[{"message":{"content":"  hello  "}}]});
        assert_eq!(parse_assistant_content(&v).unwrap(), "hello");
    }

    #[test]
    fn parses_assistant_text_parts() {
        let v = json!({"choices":[{"message":{"content":[
            {"type":"text","text":"ab"},
            {"type":"text","text":" cd "}
        ]}}]});
        assert_eq!(parse_assistant_content(&v).unwrap(), "ab cd");
    }

    #[test]
    fn image_size_maps_dalle3() {
        assert_eq!(
            resolve_openai_image_size("dall-e-3", "1792x1024"),
            "1792x1024"
        );
        assert_eq!(
            resolve_openai_image_size("dall-e-3", "1024 × 1792"),
            "1024x1792"
        );
        assert_eq!(
            resolve_openai_image_size("dall-e-3", "unknown"),
            "1024x1024"
        );
    }

    #[test]
    fn image_size_maps_dalle2() {
        assert_eq!(resolve_openai_image_size("dall-e-2", "512x512"), "512x512");
        assert_eq!(resolve_openai_image_size("dall-e-2", "bad"), "1024x1024");
    }

    #[test]
    fn image_model_from_catalog_string() {
        assert_eq!(
            resolve_openai_image_model("1:dall-e-3").as_str(),
            "dall-e-3"
        );
        assert_eq!(resolve_openai_image_model("dall-e-2").as_str(), "dall-e-2");
        assert_eq!(
            resolve_openai_image_model("unknown-catalog-id").as_str(),
            "dall-e-3"
        );
    }

    #[test]
    fn parse_reference_image_upload_accepts_raw_base64() {
        let parsed = parse_reference_image_upload("AA==").expect("parse raw");
        assert_eq!(parsed.mime, "image/jpeg");
        assert_eq!(parsed.file_name, "reference.jpg");
        assert_eq!(parsed.bytes, vec![0u8]);
    }

    #[test]
    fn parse_reference_image_upload_accepts_data_uri_png() {
        let parsed = parse_reference_image_upload("data:image/png;base64,AA==").expect("png uri");
        assert_eq!(parsed.mime, "image/png");
        assert_eq!(parsed.file_name, "reference.png");
        assert_eq!(parsed.bytes, vec![0u8]);
    }

    #[test]
    fn parse_reference_image_upload_rejects_non_image_mime() {
        let err =
            parse_reference_image_upload("data:text/plain;base64,AA==").expect_err("bad mime");
        assert!(err.contains("unsupported reference image mime"));
    }

    #[tokio::test]
    async fn images_generation_or_edit_uses_generation_without_reference_image() {
        let (base_url, state, shutdown_tx) = spawn_test_images_api().await;
        let cfg = LlmConfig {
            api_key: "test-key".to_string(),
            base_url,
            model: "gpt-4o-mini".to_string(),
        };
        let client = reqwest::Client::new();
        let (url, revised) = images_generation_or_edit_url(
            &cfg,
            &client,
            "dall-e-3",
            "a test prompt",
            "1024x1024",
            None,
        )
        .await
        .expect("request ok");
        assert_eq!(url, "https://example.test/generation.png");
        assert_eq!(revised, None);

        let snapshot = state.lock().expect("lock").clone();
        assert_eq!(snapshot.generation_hits, 1);
        assert_eq!(snapshot.edits_hits, 0);
        let _ = shutdown_tx.send(());
    }

    #[tokio::test]
    async fn images_generation_or_edit_uses_edits_with_reference_image() {
        let (base_url, state, shutdown_tx) = spawn_test_images_api().await;
        let cfg = LlmConfig {
            api_key: "test-key".to_string(),
            base_url,
            model: "gpt-4o-mini".to_string(),
        };
        let client = reqwest::Client::new();
        let (url, revised) = images_generation_or_edit_url(
            &cfg,
            &client,
            "dall-e-3",
            "a test prompt",
            "1024x1024",
            Some("data:image/png;base64,AA=="),
        )
        .await
        .expect("request ok");
        assert_eq!(url, "https://example.test/edit.png");
        assert_eq!(revised, None);

        let snapshot = state.lock().expect("lock").clone();
        assert_eq!(snapshot.generation_hits, 0);
        assert_eq!(snapshot.edits_hits, 1);
        assert!(
            snapshot
                .last_edit_content_type
                .as_deref()
                .unwrap_or_default()
                .starts_with("multipart/form-data;"),
            "content-type should be multipart/form-data"
        );
        let _ = shutdown_tx.send(());
    }
}
