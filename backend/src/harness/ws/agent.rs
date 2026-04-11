//! WebSocket 分支（`harness.agent.run`）：多轮工具循环 + 聊天信封。

use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::harness::ws::outbound::error_occurred_json;
use crate::harness::{observe, HarnessContext};
use crate::llm::{harness_agent_run, LlmConfig};

/// Inputs for [`spawn_harness_agent_run`] (grouped so the WebSocket layer stays a thin router).
pub struct HarnessAgentWsParams {
    pub cfg: LlmConfig,
    pub client: reqwest::Client,
    pub content: String,
    pub assistant_name: &'static str,
    pub user_id: Uuid,
    pub pool: Option<sqlx::PgPool>,
    pub project_legacy_id: Option<i32>,
    pub script_legacy_id: Option<i32>,
    pub max_rounds: usize,
    pub cancel: CancellationToken,
    pub out_tx: UnboundedSender<String>,
    pub request_id: Option<String>,
}

/// Spawn the non-streaming harness agent loop; caller must reset LLM cancellation / attach channel first.
pub fn spawn_harness_agent_run(p: HarnessAgentWsParams) {
    tokio::spawn(async move {
        observe::agent_llm_turn_requested(p.user_id, p.content.len());
        let ctx = HarnessContext::with_runtime_scope(
            p.user_id,
            p.pool,
            p.project_legacy_id,
            p.script_legacy_id,
            Some(p.cfg.clone()),
            Some(p.client.clone()),
        );
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
