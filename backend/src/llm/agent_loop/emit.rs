//! 将最终 assistant 文本伪装成与流式聊天同族的事件信封。

use serde_json::json;
use tokio::sync::mpsc::UnboundedSender;
use uuid::Uuid;

use crate::llm::envelope::envelope;

pub(super) fn emit_final_assistant_chat(
    out: &UnboundedSender<String>,
    full_text: &str,
    assistant_name: &str,
    request_id: Option<&str>,
) {
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
    if !full_text.is_empty() {
        let _ = out.send(envelope(
            "chat.content.updated",
            json!({
                "messageId": message_id.to_string(),
                "contentId": content_id.to_string(),
                "append": full_text,
            }),
            request_id,
        ));
    }
    let _ = out.send(envelope(
        "chat.message.updated",
        json!({
            "id": message_id.to_string(),
            "status": "complete",
        }),
        request_id,
    ));
}
