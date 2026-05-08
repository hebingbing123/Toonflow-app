//! Harness 观察模块。
//!
//! 提供追踪上下文和日志记录功能，用于监控 Harness 工具执行。

use super::HarnessContext;
use std::time::Instant;
use uuid::Uuid;

/// Trace context propagated through requests.
#[derive(Clone, Debug, Default)]
#[allow(dead_code)]
pub struct TraceContext {
    pub trace_id: String,
    pub span_id: String,
    pub parent_span_id: Option<String>,
    pub sampled: bool,
}

#[allow(dead_code)]
impl TraceContext {
    /// Create new trace context with random IDs.
    pub fn new() -> Self {
        Self {
            trace_id: Uuid::new_v4().to_string(),
            span_id: Uuid::new_v4().to_string(),
            parent_span_id: None,
            sampled: true,
        }
    }

    /// Parse from W3C TraceContext header format: `00-{trace_id}-{parent_id}-{flags}`
    pub fn from_traceparent(header: &str) -> Option<Self> {
        let parts: Vec<&str> = header.split('-').collect();
        if parts.len() != 4 || parts[0] != "00" {
            return None;
        }

        let trace_id = parts[1].to_string();
        let parent_span_id = Some(parts[2].to_string());
        let flags = u8::from_str_radix(parts[3], 16).ok()?;
        let sampled = (flags & 0x01) == 0x01;

        Some(Self {
            trace_id,
            span_id: Uuid::new_v4().to_string(),
            parent_span_id,
            sampled,
        })
    }

    /// Format as W3C TraceContext header.
    pub fn to_traceparent(&self) -> String {
        let flags = if self.sampled { "01" } else { "00" };
        format!("00-{}-{}-{}", self.trace_id, self.span_id, flags)
    }
}

pub fn ws_frame(ctx: &HarnessContext, msg_type: &str) {
    match ctx.workspace_id {
        Some(ws) => {
            tracing::debug!(user_id = %ctx.user_id, workspace_id = %ws, %msg_type, "harness.ws")
        }
        None => tracing::debug!(user_id = %ctx.user_id, %msg_type, "harness.ws"),
    }
}

pub fn agent_llm_turn_requested(user_id: Uuid, content_len: usize) {
    tracing::info!(%user_id, content_len, "harness.agent_llm_turn");
}

pub fn harness_tool_invoke(ctx: &HarnessContext, tool_name: &str) {
    match ctx.workspace_id {
        Some(ws) => {
            tracing::info!(user_id = %ctx.user_id, workspace_id = %ws, %tool_name, "harness.tool.invoke")
        }
        None => tracing::info!(user_id = %ctx.user_id, %tool_name, "harness.tool.invoke"),
    }
}

/// One completed `isolated.echo` cycle (Semaphore wait + child process wall time).
///
/// Filter logs with **`event = harness_isolate_invoke`**; aggregate totals live in [`crate::harness::isolate::metrics_snapshot`].
pub fn harness_isolate_invoke_finished(
    queued_tasks_ahead_when_entered: usize,
    semaphore_wait_ms: u64,
    child_execution_ms: u64,
    available_slots_snapshot: usize,
    max_slots: usize,
    reuse_hit: bool,
    process_reuse_hits_total: u64,
) {
    tracing::info!(
        target: "harness.isolate.metrics",
        event = "harness_isolate_invoke",
        queued_ahead = queued_tasks_ahead_when_entered,
        semaphore_wait_ms,
        child_execution_ms,
        available_slots_snapshot,
        max_slots,
        reuse_hit,
        process_reuse_hits_total,
        "harness isolate invoke"
    );
}

pub fn harness_tools_catalog_http(user_id: Uuid) {
    tracing::debug!(%user_id, "harness.http.tools_catalog");
}

pub fn harness_user_wasm_validate_http(user_id: Uuid, size_bytes: usize) {
    tracing::debug!(
        %user_id,
        size_bytes,
        "harness.http.user_wasm_validate"
    );
}

/// REST **`/api/v1/agents/memory/*`** (parity with Electron agent memory).
pub fn memory_http(user_id: Uuid, numeric_project_id: i32, op: &'static str) {
    tracing::debug!(%user_id, numeric_project_id, %op, "harness.memory.http");
}

/// Worker claimed or finished a row in **`app_generation_job`**.
///
/// Structured for log pipelines: filter on **`event = generation_job_phase`** and join on **`job_id`**
/// (same UUID as `app_generation_job.id`). Optional **`client_request_id`** comes from job
/// **`payload.client_request_id`** or **`payload.request_id`** when enqueue paths set it.
pub fn generation_job(
    user_id: Uuid,
    job_id: Uuid,
    kind: &str,
    phase: &'static str,
    worker_id: &str,
    client_request_id: Option<&str>,
) {
    let rid = client_request_id.filter(|s| !s.is_empty());
    tracing::info!(
        user_id = %user_id,
        job_id = %job_id,
        kind = %kind,
        phase,
        worker_id = %worker_id,
        client_request_id = rid.unwrap_or(""),
        event = "generation_job_phase",
        "app_generation_job lifecycle (worker)"
    );
}

/// WASM invocation timing wrapper.
#[allow(dead_code)]
pub struct WasmInvocationTimer {
    tool_name: String,
    start: Instant,
}

#[allow(dead_code)]
impl WasmInvocationTimer {
    pub fn start(tool_name: &str) -> Self {
        Self {
            tool_name: tool_name.to_string(),
            start: Instant::now(),
        }
    }

    pub fn finish(self, success: bool) {
        let duration_ms = self.start.elapsed().as_millis() as u64;
        tracing::info!(
            target: "harness.wasm.invoke",
            tool_name = %self.tool_name,
            duration_ms,
            success,
            "WASM invocation completed"
        );
    }
}

/// Extract or create trace context from HTTP request headers.
#[allow(dead_code)]
pub fn extract_trace_context<B>(req: &axum::http::Request<B>) -> TraceContext {
    // Try W3C TraceContext
    if let Some(traceparent) = req.headers().get("traceparent") {
        if let Ok(header) = traceparent.to_str() {
            if let Some(ctx) = TraceContext::from_traceparent(header) {
                return ctx;
            }
        }
    }

    // Try X-Request-ID as trace_id
    if let Some(request_id) = req.headers().get("x-request-id") {
        if let Ok(id) = request_id.to_str() {
            return TraceContext {
                trace_id: id.to_string(),
                span_id: Uuid::new_v4().to_string(),
                parent_span_id: None,
                sampled: true,
            };
        }
    }

    // Create new trace context
    TraceContext::new()
}
