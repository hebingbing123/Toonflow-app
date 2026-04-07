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
    tracing::debug!(user_id = %ctx.user_id, %msg_type, "harness.ws");
}

pub fn agent_llm_turn_requested(user_id: Uuid, content_len: usize) {
    tracing::info!(%user_id, content_len, "harness.agent_llm_turn");
}

pub fn harness_tool_invoke(ctx: &HarnessContext, tool_name: &str) {
    tracing::info!(user_id = %ctx.user_id, %tool_name, "harness.tool.invoke");
}

pub fn harness_tools_catalog_http(user_id: Uuid) {
    tracing::debug!(%user_id, "harness.http.tools_catalog");
}

/// REST **`/api/v1/agents/memory/*`** (parity with legacy agent memory).
pub fn memory_http(user_id: Uuid, legacy_project_id: i32, op: &'static str) {
    tracing::debug!(%user_id, legacy_project_id, %op, "harness.memory.http");
}

/// Worker claimed or finished a row in **`app_generation_job`** (best-effort tracing).
pub fn generation_job(user_id: Uuid, job_id: Uuid, phase: &'static str) {
    tracing::debug!(%user_id, %job_id, %phase, "harness.job");
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
