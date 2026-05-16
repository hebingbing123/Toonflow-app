use serde_json::json;

use crate::billing::provider_rules;

use super::super::subscription_state::parse_subscription_status;

#[test]
fn derive_from_provider_stripe_status_field() {
    let v = json!({
        "billing_provider": "stripe",
        "data": { "object": { "status": "past_due" } }
    });
    assert_eq!(
        provider_rules::derive_from_provider(&v)
            .subscription_status
            .as_deref(),
        Some("past_due")
    );
}

#[test]
fn derive_from_provider_stripe_event_type_fallback() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.deleted"
    });
    assert_eq!(
        provider_rules::derive_from_provider(&v)
            .subscription_status
            .as_deref(),
        Some("canceled")
    );
}

#[test]
fn explicit_subscription_status_takes_precedence_over_provider_mapping() {
    let v = json!({
        "subscription_status": "active",
        "billing_provider": "stripe",
        "type": "customer.subscription.deleted"
    });
    let got = parse_subscription_status(&v)
        .or(provider_rules::derive_from_provider(&v).subscription_status);
    assert_eq!(got.as_deref(), Some("active"));
}

#[test]
fn derive_from_provider_ignores_non_stripe() {
    let v = json!({
        "billing_provider": "alipay",
        "type": "customer.subscription.deleted",
        "data": { "object": { "status": "canceled" } }
    });
    assert!(provider_rules::derive_from_provider(&v)
        .subscription_status
        .is_none());
}

#[test]
fn derive_from_provider_alipay_trade_status() {
    let v = json!({
        "billing_provider": "alipay",
        "trade_status": "TRADE_SUCCESS"
    });
    assert_eq!(
        provider_rules::derive_from_provider(&v)
            .subscription_status
            .as_deref(),
        Some("active")
    );
}

#[test]
fn derive_from_provider_alipay_event_type_fallback() {
    let v = json!({
        "billing_provider": "alipay",
        "type": "trade.closed"
    });
    assert_eq!(
        provider_rules::derive_from_provider(&v)
            .subscription_status
            .as_deref(),
        Some("canceled")
    );
}

#[test]
fn derive_from_provider_alipay_notify_time_as_rfc3339() {
    let v = json!({
        "billing_provider": "alipay",
        "notify_time": "2026-04-06T10:20:30Z"
    });
    let got = provider_rules::derive_from_provider(&v)
        .subscription_status_updated_at
        .expect("notify_time should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-06T10:20:30+00:00");
}

#[test]
fn derive_from_provider_period_end_from_stripe() {
    let v = json!({
        "billing_provider": "stripe",
        "data": { "object": { "current_period_end": 1_700_000_001_i64 } }
    });
    let got = provider_rules::derive_from_provider(&v)
        .subscription_current_period_end
        .expect("timestamp should parse");
    assert_eq!(got.timestamp(), 1_700_000_001_i64);
}

#[test]
fn derive_from_provider_status_updated_at_from_stripe_created() {
    let v = json!({
        "billing_provider": "stripe",
        "created": 1_700_888_777_i64
    });
    let got = provider_rules::derive_from_provider(&v)
        .subscription_status_updated_at
        .expect("created should parse as updated_at");
    assert_eq!(got.timestamp(), 1_700_888_777_i64);
}

#[test]
fn derive_from_provider_uses_currency_adapter_when_provider_missing() {
    let v = json!({
        "billing_currency": "USD",
        "type": "invoice.payment_succeeded"
    });
    assert_eq!(
        provider_rules::derive_from_provider(&v)
            .subscription_status
            .as_deref(),
        Some("active")
    );
}
