use serde_json::json;

use crate::billing::provider_rules;

use super::super::event_parse::{
    build_provider_event_id, parse_event_created_at, parse_event_type, parse_raw_event_id,
};

#[test]
fn normalize_provider_name_lowercases_and_trims() {
    assert_eq!(
        provider_rules::normalize_provider_name(" Stripe "),
        Some("stripe".to_string())
    );
}

#[test]
fn build_provider_event_id_namespaces_when_provider_present() {
    assert_eq!(
        build_provider_event_id(Some("stripe"), "evt_1"),
        "stripe:evt_1".to_string()
    );
}

#[test]
fn build_provider_event_id_keeps_raw_when_provider_missing() {
    assert_eq!(build_provider_event_id(None, "evt_1"), "evt_1".to_string());
}

#[test]
fn parse_event_type_uses_event_type_fallback_when_type_missing() {
    let v = json!({ "event_type": "invoice.paid" });
    assert_eq!(parse_event_type(&v).as_deref(), Some("invoice.paid"));
}

#[test]
fn parse_event_type_uses_event_fallback_when_type_missing() {
    let v = json!({ "event": "invoice.payment_failed" });
    assert_eq!(
        parse_event_type(&v).as_deref(),
        Some("invoice.payment_failed")
    );
}

#[test]
fn parse_event_type_uses_notify_type_fallback_when_type_missing() {
    let v = json!({ "notify_type": "trade.success" });
    assert_eq!(parse_event_type(&v).as_deref(), Some("trade.success"));
}

#[test]
fn parse_raw_event_id_prefers_id_key() {
    let v = json!({
        "id": "evt_primary",
        "event_id": "evt_secondary"
    });
    assert_eq!(parse_raw_event_id(&v).as_deref(), Some("evt_primary"));
}

#[test]
fn parse_raw_event_id_supports_event_id_fallback() {
    let v = json!({ "event_id": "evt_fallback" });
    assert_eq!(parse_raw_event_id(&v).as_deref(), Some("evt_fallback"));
}

#[test]
fn parse_raw_event_id_supports_event_id_camel_case_fallback() {
    let v = json!({ "eventId": "evt_camel" });
    assert_eq!(parse_raw_event_id(&v).as_deref(), Some("evt_camel"));
}

#[test]
fn parse_raw_event_id_supports_notify_id_fallback() {
    let v = json!({ "notify_id": "evt_notify" });
    assert_eq!(parse_raw_event_id(&v).as_deref(), Some("evt_notify"));
}

#[test]
fn parse_raw_event_id_supports_notify_id_camel_case_fallback() {
    let v = json!({ "notifyId": "evt_notify_camel" });
    assert_eq!(parse_raw_event_id(&v).as_deref(), Some("evt_notify_camel"));
}

#[test]
fn parse_raw_event_id_accepts_numeric_id_fallback() {
    let v = json!({ "event_id": 123456_i64 });
    assert_eq!(parse_raw_event_id(&v).as_deref(), Some("123456"));
}

#[test]
fn parse_raw_event_id_returns_none_when_all_candidates_missing_or_blank() {
    let v = json!({ "event_id": "   ", "notify_id": "" });
    assert!(parse_raw_event_id(&v).is_none());
}

#[test]
fn parse_event_created_at_prefers_event_created_at_rfc3339() {
    let v = json!({
        "event_created_at": "2026-04-08T10:11:12Z",
        "created": 1_700_000_000_i64
    });
    let got = parse_event_created_at(&v).expect("event_created_at should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-08T10:11:12+00:00");
}

#[test]
fn parse_event_created_at_accepts_event_created_at_unix_timestamp() {
    let v = json!({ "event_created_at": 1_800_000_001_i64 });
    let got = parse_event_created_at(&v).expect("event_created_at unix should parse");
    assert_eq!(got.timestamp(), 1_800_000_001_i64);
}

#[test]
fn parse_event_created_at_accepts_alipay_datetime_format() {
    let v = json!({ "notify_time": "2026-04-08 08:09:10" });
    let got = parse_event_created_at(&v).expect("notify_time should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-08T08:09:10+00:00");
}

#[test]
fn parse_event_created_at_accepts_timestamp_string() {
    let v = json!({ "timestamp": "1800000002" });
    let got = parse_event_created_at(&v).expect("timestamp string should parse");
    assert_eq!(got.timestamp(), 1_800_000_002_i64);
}

#[test]
fn parse_event_created_at_accepts_millis_timestamp() {
    let v = json!({ "event_created_at": 1_800_000_003_456_i64 });
    let got = parse_event_created_at(&v).expect("event_created_at millis should parse");
    assert_eq!(got.timestamp_millis(), 1_800_000_003_456_i64);
}

#[test]
fn parse_event_created_at_accepts_paddle_occurred_at_rfc3339() {
    let v = json!({
        "billing_provider": "paddle",
        "occurred_at": "2026-04-07T08:09:10Z"
    });
    let got = parse_event_created_at(&v).expect("occurred_at should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-07T08:09:10+00:00");
}
