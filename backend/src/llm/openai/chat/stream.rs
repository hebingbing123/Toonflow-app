use futures_util::StreamExt;
use serde_json::json;
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::llm::envelope::envelope;

use super::super::config::LlmConfig;
use super::parse::parse_sse_data_line;

/// Stream one assistant reply; emits raw WS envelopes in the documented
/// `chat.message.*` / `chat.content.*` sequence from `docs/websocket-events.md`.
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
