//! WebSocket 分支（`agent.chat.send`）：流式 LLM 轮次。

use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::harness::observe;
use crate::harness::ws::outbound::error_occurred_json;
use crate::llm::{stream_chat_turn, LlmConfig};

/// Inputs for [`spawn_stream_chat_turn`].
pub struct ChatTurnWsParams {
    pub cfg: LlmConfig,
    pub client: reqwest::Client,
    pub content: String,
    pub assistant_name: &'static str,
    pub user_id: Uuid,
    pub cancel: CancellationToken,
    pub out_tx: UnboundedSender<String>,
    pub request_id: Option<String>,
}

pub fn spawn_stream_chat_turn(p: ChatTurnWsParams) {
    tokio::spawn(async move {
        observe::agent_llm_turn_requested(p.user_id, p.content.len());
        if let Err(e) = stream_chat_turn(
            &p.cfg,
            &p.client,
            &p.content,
            p.assistant_name,
            p.cancel,
            p.out_tx.clone(),
            p.request_id.as_deref(),
        )
        .await
        {
            let _ = p.out_tx.send(error_occurred_json(
                "llm_error",
                &e,
                p.request_id.as_deref(),
            ));
        }
    });
}
