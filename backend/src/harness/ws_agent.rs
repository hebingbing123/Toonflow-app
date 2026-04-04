//! WebSocket branch for **`harness.agent.run`** (multi-round tool loop + chat envelopes).

use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::harness::ws_outbound::error_occurred_json;
use crate::harness::{observe, HarnessContext};
use crate::llm::{harness_agent_run, LlmConfig};

/// Inputs for [`spawn_harness_agent_run`] (grouped so the WebSocket layer stays a thin router).
pub struct HarnessAgentWsParams {
    pub cfg: LlmConfig,
    pub client: reqwest::Client,
    pub content: String,
    pub assistant_name: &'static str,
    pub user_id: Uuid,
    pub max_rounds: usize,
    pub cancel: CancellationToken,
    pub out_tx: UnboundedSender<String>,
    pub request_id: Option<String>,
}

/// Spawn the non-streaming harness agent loop; caller must reset LLM cancellation / attach channel first.
pub fn spawn_harness_agent_run(p: HarnessAgentWsParams) {
    tokio::spawn(async move {
        observe::agent_llm_turn_requested(p.user_id, p.content.len());
        let ctx = HarnessContext::new(p.user_id);
        if let Err(e) = harness_agent_run(
            &p.cfg,
            &p.client,
            &p.content,
            p.assistant_name,
            &ctx,
            p.max_rounds,
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
