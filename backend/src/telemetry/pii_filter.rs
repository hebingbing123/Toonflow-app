//! PII allowlist filtering for OTLP span export (WP-F).

use opentelemetry_sdk::error::OTelSdkResult;
use opentelemetry_sdk::trace::{SpanData, SpanExporter};
use opentelemetry_sdk::Resource;
use std::fmt;

pub const PII_ALLOWLIST: &[&str] = &[
    "user_id",
    "workspace_id",
    "request_id",
    "job_id",
    "wasm_id",
    "signal_name",
    "tool_name",
    "event",
    "outcome",
    "error_code",
    "kind",
    "phase",
    "worker_id",
    "client_request_id",
    "http.method",
    "http.status_code",
    "http.url",
    "http.route",
    "db.system",
    "db.operation",
    "net.peer.name",
    "net.peer.port",
    "otel.status_code",
    "otel.status_description",
    "code.function",
    "code.namespace",
    "code.filepath",
];

#[inline]
pub fn is_pii_allowlisted(key: &str) -> bool {
    PII_ALLOWLIST
        .iter()
        .any(|allowed| allowed.eq_ignore_ascii_case(key))
}

fn looks_like_json(value: &str) -> bool {
    let t = value.trim();
    (t.starts_with('{') && t.ends_with('}')) || (t.starts_with('[') && t.ends_with(']'))
}

/// Redact a single span attribute value according to the PII allowlist.
pub fn apply_pii_filter(key: &str, value: &str) -> String {
    if is_pii_allowlisted(key) {
        return value.to_string();
    }
    if looks_like_json(value) {
        return "[redacted:json]".to_string();
    }
    "[redacted]".to_string()
}

fn attribute_value_as_str(value: &opentelemetry::Value) -> String {
    match value {
        opentelemetry::Value::String(s) => s.as_str().to_string(),
        other => format!("{other:?}"),
    }
}

pub fn redact_span_data(mut span: SpanData) -> SpanData {
    for attr in &mut span.attributes {
        let key = attr.key.as_str();
        if is_pii_allowlisted(key) {
            continue;
        }
        let filtered = apply_pii_filter(key, &attribute_value_as_str(&attr.value));
        attr.value = opentelemetry::Value::String(filtered.into());
    }
    span
}

/// Wraps an OTLP [`SpanExporter`] and redacts non-allowlisted attributes at export time.
pub struct PiiRedactingSpanExporter {
    inner: opentelemetry_otlp::SpanExporter,
}

impl fmt::Debug for PiiRedactingSpanExporter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PiiRedactingSpanExporter")
            .finish_non_exhaustive()
    }
}

impl PiiRedactingSpanExporter {
    pub fn new(inner: opentelemetry_otlp::SpanExporter) -> Self {
        Self { inner }
    }
}

impl SpanExporter for PiiRedactingSpanExporter {
    async fn export(&self, batch: Vec<SpanData>) -> OTelSdkResult {
        let redacted = batch.into_iter().map(redact_span_data).collect();
        self.inner.export(redacted).await
    }

    fn set_resource(&mut self, resource: &Resource) {
        self.inner.set_resource(resource);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn email_is_redacted_user_id_preserved() {
        assert_eq!(apply_pii_filter("email", "a@b.c"), "[redacted]");
        assert_eq!(apply_pii_filter("user_id", "uuid-here"), "uuid-here");
    }

    #[test]
    fn json_non_allowlisted_becomes_redacted_json() {
        assert_eq!(
            apply_pii_filter("payload", r#"{"email":"x@y.z"}"#),
            "[redacted:json]"
        );
    }

    #[test]
    fn allowlist_is_case_insensitive() {
        assert_eq!(apply_pii_filter("User_Id", "abc"), "abc");
        assert_eq!(apply_pii_filter("HTTP.METHOD", "GET"), "GET");
    }

    // Feature: harness-observability-hardening, Property 3: PII 过滤白名单不变量
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]
        #[test]
        fn prop_pii_filter_allowlist_invariant(
            key in "[a-zA-Z_\\.]{1,30}",
            value in ".{0,40}",
        ) {
            let result = apply_pii_filter(&key, &value);
            if is_pii_allowlisted(&key) {
                prop_assert_eq!(result, value);
            } else if looks_like_json(&value) {
                prop_assert_eq!(result, "[redacted:json]");
            } else {
                prop_assert_eq!(result, "[redacted]");
            }
        }
    }
}
