//! 可观测性与 **OTLP trace** 导出（路线图 **WP-F**）。
//!
//! - **`OPENFLOW_OTEL_EXPORT_ENABLED`**: `1` / `true` / `yes` / `on` 时启用 OTLP gRPC 导出。
//! - **`OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`** 或 **`OTEL_EXPORTER_OTLP_ENDPOINT`**：collector 地址（默认 `http://127.0.0.1:4317`）。
//! - **`OTEL_SERVICE_NAME`**：可选；默认 `openflow-server`。
//! - **`OPENFLOW_OTEL_SAMPLE_RATE`**：导出启用时，`TraceIdRatioBased` 采样率；缺失或不可解析回落 **1.0**；`≤ 0` 回落 **0.01** 并记警告；`> 1` 钳制为 **1.0**。

pub mod pii_filter;

use opentelemetry::global;
use opentelemetry::KeyValue;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::propagation::TraceContextPropagator;
use opentelemetry_sdk::resource::Resource;
use opentelemetry_sdk::trace::{Sampler, SdkTracerProvider};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter, Registry};

#[inline]
pub(crate) fn truthy_env(name: &str) -> bool {
    match std::env::var(name) {
        Ok(s) => {
            let t = s.trim().to_ascii_lowercase();
            matches!(t.as_str(), "1" | "true" | "yes" | "on")
        }
        Err(_) => false,
    }
}

/// gRPC OTLP 默认端口（与 OpenTelemetry Collector 一致）。
pub(crate) const DEFAULT_OTLP_GRPC_ENDPOINT: &str = "http://127.0.0.1:4317";

pub(crate) fn resolve_otlp_grpc_endpoint() -> String {
    if let Ok(v) = std::env::var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") {
        let t = v.trim();
        if !t.is_empty() {
            return t.to_string();
        }
    }
    if let Ok(v) = std::env::var("OTEL_EXPORTER_OTLP_ENDPOINT") {
        let t = v.trim();
        if !t.is_empty() {
            return t.to_string();
        }
    }
    DEFAULT_OTLP_GRPC_ENDPOINT.to_string()
}

fn otel_service_name() -> String {
    std::env::var("OTEL_SERVICE_NAME")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "openflow-server".to_string())
}

/// OTLP 导出路径使用的采样率（仅在 [`try_init_otel_tracer_provider`] 中调用；导出未启用时不读该变量）。
#[must_use]
pub(crate) fn parse_otel_sample_rate_for_export() -> f64 {
    match std::env::var("OPENFLOW_OTEL_SAMPLE_RATE") {
        Err(_) => 1.0,
        Ok(raw) => {
            let t = raw.trim();
            match t.parse::<f64>() {
                Err(_) => 1.0,
                Ok(v) if v <= 0.0 => {
                    tracing::warn!(
                        target: "openflow.telemetry",
                        event = "otel_sample_rate_invalid",
                        value = %t,
                        "non-positive OTEL sample rate; using 0.01"
                    );
                    0.01
                }
                Ok(v) if v > 1.0 => {
                    tracing::warn!(
                        target: "openflow.telemetry",
                        event = "otel_sample_rate_invalid",
                        value = %t,
                        "OTEL sample rate > 1; clamping to 1.0"
                    );
                    1.0
                }
                Ok(v) => v,
            }
        }
    }
}

fn try_init_otel_tracer_provider() -> anyhow::Result<()> {
    let endpoint = resolve_otlp_grpc_endpoint();
    let inner_exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_tonic()
        .with_endpoint(endpoint.clone())
        .build()
        .map_err(|e| anyhow::anyhow!("{e}"))?;

    let exporter = pii_filter::PiiRedactingSpanExporter::new(inner_exporter);

    let resource = Resource::builder()
        .with_attributes(vec![KeyValue::new("service.name", otel_service_name())])
        .build();

    let rate = parse_otel_sample_rate_for_export();
    tracing::info!(
        target: "openflow.telemetry",
        event = "otel_sample_rate_resolved",
        sample_rate = rate,
        "OPENFLOW_OTEL_SAMPLE_RATE resolved"
    );

    let provider = SdkTracerProvider::builder()
        .with_resource(resource)
        .with_sampler(Sampler::TraceIdRatioBased(rate))
        .with_batch_exporter(exporter)
        .build();

    global::set_text_map_propagator(TraceContextPropagator::new());
    global::set_tracer_provider(provider);
    Ok(())
}

/// **`#[ignore]` 集成烟测**：向本机 collector 导出 trace（见 `tests/telemetry_otlp_collector_smoke.rs`）。
#[doc(hidden)]
pub fn init_otel_for_collector_smoke_test() -> anyhow::Result<()> {
    try_init_otel_tracer_provider()
}

/// 初始化全局 `tracing` subscriber（控制台 + 可选 OTLP）。
///
/// **仅能调用一次**（与 `tracing_subscriber` 全局注册一致）。
pub fn init_tracing_subscriber() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    if !truthy_env("OPENFLOW_OTEL_EXPORT_ENABLED") {
        Registry::default()
            .with(filter)
            .with(tracing_subscriber::fmt::layer())
            .init();
        return;
    }

    if let Err(err) = try_init_otel_tracer_provider() {
        eprintln!("openflow: OTLP exporter init failed ({err}); continuing with fmt logs only");
        Registry::default()
            .with(filter)
            .with(tracing_subscriber::fmt::layer())
            .init();
        tracing::warn!(
            target: "openflow.telemetry",
            error = %err,
            "OPENFLOW_OTEL_EXPORT_ENABLED set but OTLP init failed; spans are not exported"
        );
        return;
    }

    let tracer = global::tracer("openflow-server");
    let otel_layer = tracing_opentelemetry::layer().with_tracer(tracer);
    Registry::default()
        .with(filter)
        .with(otel_layer)
        .with(tracing_subscriber::fmt::layer())
        .init();
    tracing::info!(
        target: "openflow.telemetry",
        endpoint = %resolve_otlp_grpc_endpoint(),
        "OPENFLOW_OTEL_EXPORT_ENABLED: OTLP gRPC trace export initialized (PII-redacting exporter)"
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_MUTEX: Mutex<()> = Mutex::new(());

    #[test]
    fn truthy_env_parses() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::remove_var("OPENFLOW_OTEL_EXPORT_ENABLED");
        assert!(!truthy_env("OPENFLOW_OTEL_EXPORT_ENABLED"));
        std::env::set_var("OPENFLOW_OTEL_EXPORT_ENABLED", "1");
        assert!(truthy_env("OPENFLOW_OTEL_EXPORT_ENABLED"));
        std::env::set_var("OPENFLOW_OTEL_EXPORT_ENABLED", "no");
        assert!(!truthy_env("OPENFLOW_OTEL_EXPORT_ENABLED"));
        std::env::remove_var("OPENFLOW_OTEL_EXPORT_ENABLED");
    }

    #[test]
    fn resolve_otlp_grpc_endpoint_prefers_traces_var() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::remove_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        std::env::remove_var("OTEL_EXPORTER_OTLP_ENDPOINT");
        assert_eq!(resolve_otlp_grpc_endpoint(), DEFAULT_OTLP_GRPC_ENDPOINT);
        std::env::set_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://example:4317");
        assert_eq!(resolve_otlp_grpc_endpoint().as_str(), "http://example:4317");
        std::env::set_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://traces:4317");
        assert_eq!(resolve_otlp_grpc_endpoint().as_str(), "http://traces:4317");
        std::env::remove_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        std::env::remove_var("OTEL_EXPORTER_OTLP_ENDPOINT");
    }

    #[test]
    fn otel_sample_rate_clamps_and_defaults() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::remove_var("OPENFLOW_OTEL_SAMPLE_RATE");
        assert_eq!(parse_otel_sample_rate_for_export(), 1.0);
        std::env::set_var("OPENFLOW_OTEL_SAMPLE_RATE", "not-a-float");
        assert_eq!(parse_otel_sample_rate_for_export(), 1.0);
        std::env::set_var("OPENFLOW_OTEL_SAMPLE_RATE", "0");
        assert_eq!(parse_otel_sample_rate_for_export(), 0.01);
        std::env::set_var("OPENFLOW_OTEL_SAMPLE_RATE", "-1");
        assert_eq!(parse_otel_sample_rate_for_export(), 0.01);
        std::env::set_var("OPENFLOW_OTEL_SAMPLE_RATE", "9");
        assert_eq!(parse_otel_sample_rate_for_export(), 1.0);
        std::env::set_var("OPENFLOW_OTEL_SAMPLE_RATE", "0.25");
        assert_eq!(parse_otel_sample_rate_for_export(), 0.25);
        std::env::remove_var("OPENFLOW_OTEL_SAMPLE_RATE");
    }

    #[test]
    fn nested_tracing_spans_have_parent_id() {
        let _g = ENV_MUTEX.lock().expect("lock");

        #[derive(Clone, Default)]
        struct CaptureLayer {
            parent: std::sync::Arc<std::sync::Mutex<Option<tracing::span::Id>>>,
            child: std::sync::Arc<std::sync::Mutex<Option<tracing::span::Id>>>,
        }
        impl<S> tracing_subscriber::Layer<S> for CaptureLayer
        where
            S: tracing::Subscriber + for<'a> tracing_subscriber::registry::LookupSpan<'a>,
        {
            fn on_new_span(
                &self,
                attrs: &tracing::span::Attributes<'_>,
                id: &tracing::span::Id,
                ctx: tracing_subscriber::layer::Context<'_, S>,
            ) {
                let name = attrs.metadata().name();
                let span = ctx.span(id).expect("span");
                let parent = span.parent().map(|p| p.id());
                if name == "parent_op" {
                    *self.parent.lock().expect("lock") = parent;
                } else if name == "child_op" {
                    *self.child.lock().expect("lock") = parent;
                }
            }
        }

        let parent_arc = std::sync::Arc::new(std::sync::Mutex::new(None));
        let child_arc = std::sync::Arc::new(std::sync::Mutex::new(None));
        let capture = CaptureLayer {
            parent: parent_arc.clone(),
            child: child_arc.clone(),
        };

        let _guard = tracing::subscriber::set_default(tracing_subscriber::registry().with(capture));

        let root = tracing::info_span!("parent_op");
        let _e = root.enter();
        let child = tracing::info_span!("child_op");
        let _c = child.enter();

        let p = parent_arc.lock().expect("lock").clone();
        let c = child_arc.lock().expect("lock").clone();
        assert!(p.is_none(), "root span should have no tracing parent");
        assert_eq!(c, root.id(), "child should record parent span id");
    }
}
