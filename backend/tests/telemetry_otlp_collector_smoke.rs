//! Local smoke: OTLP gRPC export to OpenTelemetry Collector.
//!
//! ```text
//! docker run --rm -p 4317:4317 otel/opentelemetry-collector:latest
//! cd backend && \
//!   TOONFLOW_OTEL_EXPORT_ENABLED=1 \
//!   RUST_LOG=info \
//!   cargo test -p toonflow-server --test telemetry_otlp_collector_smoke otlp_export_reaches_collector -- --ignored --nocapture
//! ```
//!
//! Requires a reachable collector on `OTEL_EXPORTER_OTLP_ENDPOINT` (default `http://127.0.0.1:4317`).

use opentelemetry::global;
use opentelemetry::trace::Tracer;

#[tokio::test]
#[ignore = "requires local OTLP collector on gRPC 4317"]
async fn otlp_export_reaches_collector() {
    let _ = dotenvy::dotenv();
    std::env::set_var("TOONFLOW_OTEL_EXPORT_ENABLED", "1");

    toonflow_server::telemetry::init_otel_for_collector_smoke_test().expect("init otel");

    let tracer = global::tracer("telemetry_otlp_collector_smoke");
    tracer.in_span("smoke.test_span", |_cx| {});
}
