use serde_json::{json, Value};

use super::super::*;

#[test]
fn derive_from_currency_default_without_provider_uses_alipay_route() {
    let v = json!({
        "billing_currency": "CNY",
        "trade_status": "TRADE_SUCCESS"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("active"));
}

#[test]
fn derive_alipay_trade_finished_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "alipay",
        "type": "trade.finished"
    });
    assert!(alipay::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn informational_event_dispatch_uses_currency_adapter_when_provider_missing() {
    let v = json!({
        "billing_currency": "CNY",
        "type": "trade.finished"
    });
    assert!(is_informational_event(&v));
}

#[test]
fn normalize_webhook_keeps_provider_none_when_inferred_from_currency() {
    let v = json!({
        "billing_currency": "USD",
        "type": "invoice.payment_succeeded"
    });
    let n = normalize_webhook(&v);
    assert!(n.provider.is_none());
    assert_eq!(n.derived.subscription_status.as_deref(), Some("active"));
}

#[test]
fn derive_uses_event_type_field_when_type_missing() {
    let v = json!({
        "billing_provider": "stripe",
        "event_type": "invoice.paid"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("active"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_uses_event_field_when_type_missing() {
    let v = json!({
        "billing_provider": "stripe",
        "event": "invoice.payment_failed"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("past_due"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_alipay_notify_time_accepts_sqlite_datetime_format() {
    let v = json!({
        "billing_provider": "alipay",
        "notify_time": "2026-04-08 12:13:14"
    });
    let got = derive_from_provider(&v)
        .subscription_status_updated_at
        .expect("notify_time should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-08T12:13:14+00:00");
}

#[test]
fn derive_uses_notify_type_field_when_type_missing() {
    let v = json!({
        "billing_provider": "alipay",
        "notify_type": "trade.closed"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("canceled"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_alipay_notify_time_accepts_millis_timestamp() {
    let v = json!({
        "billing_provider": "alipay",
        "notify_time": 1_800_000_000_123_i64
    });
    let got = derive_from_provider(&v)
        .subscription_status_updated_at
        .expect("notify_time millis should parse");
    assert_eq!(got.timestamp_millis(), 1_800_000_000_123_i64);
}
