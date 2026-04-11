use chrono::{DateTime, Utc};
use serde_json::json;

use crate::billing::provider_rules;
use crate::billing::provider_rules::ProviderStatusConfidence;

use super::event_parse::{
    build_provider_event_id, parse_event_created_at, parse_event_type, parse_raw_event_id,
};
use super::subscription_state::{
    parse_subscription_period_end, parse_subscription_status, parse_subscription_status_updated_at,
    resolve_subscription_state, ExistingSubscriptionState, IncomingSubscriptionState,
    SubscriptionStatusSource,
};

#[test]
fn parse_subscription_status_accepts_known_values_case_insensitive() {
    let v = json!({ "subscription_status": " AcTive " });
    assert_eq!(parse_subscription_status(&v).as_deref(), Some("active"));
}

#[test]
fn normalize_provider_name_lowercases_and_trims() {
    assert_eq!(
        provider_rules::normalize_provider_name(" Stripe "),
        Some("stripe".to_string())
    );
}

#[test]
fn parse_subscription_status_rejects_unknown_value() {
    let v = json!({ "subscription_status": "paused" });
    assert!(parse_subscription_status(&v).is_none());
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
fn resolve_subscription_state_rejects_stale_event() {
    let existing = ExistingSubscriptionState {
        subscription_status: Some("active".into()),
        subscription_current_period_end_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
    };
    let incoming = IncomingSubscriptionState {
        subscription_status: Some("canceled".into()),
        subscription_current_period_end_at: DateTime::<Utc>::from_timestamp(1_700_050_000, 0),
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_050_000, 0),
        source: Some(SubscriptionStatusSource::ProviderDerived),
        provider_confidence: Some(ProviderStatusConfidence::DirectField),
    };
    let resolved = resolve_subscription_state(Some(existing.clone()), incoming);
    assert_eq!(resolved.subscription_status, existing.subscription_status);
    assert_eq!(
        resolved.subscription_status_updated_at,
        existing.subscription_status_updated_at
    );
}

#[test]
fn resolve_subscription_state_blocks_provider_terminal_regression() {
    let existing = ExistingSubscriptionState {
        subscription_status: Some("canceled".into()),
        subscription_current_period_end_at: None,
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
    };
    let incoming = IncomingSubscriptionState {
        subscription_status: Some("active".into()),
        subscription_current_period_end_at: None,
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_200_000, 0),
        source: Some(SubscriptionStatusSource::ProviderDerived),
        provider_confidence: Some(ProviderStatusConfidence::DirectField),
    };
    let resolved = resolve_subscription_state(Some(existing.clone()), incoming);
    assert_eq!(resolved.subscription_status, existing.subscription_status);
}

#[test]
fn resolve_subscription_state_allows_explicit_transition_from_terminal() {
    let existing = ExistingSubscriptionState {
        subscription_status: Some("canceled".into()),
        subscription_current_period_end_at: None,
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
    };
    let incoming = IncomingSubscriptionState {
        subscription_status: Some("active".into()),
        subscription_current_period_end_at: DateTime::<Utc>::from_timestamp(1_700_300_000, 0),
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_300_000, 0),
        source: Some(SubscriptionStatusSource::Explicit),
        provider_confidence: None,
    };
    let resolved = resolve_subscription_state(Some(existing), incoming);
    assert_eq!(resolved.subscription_status.as_deref(), Some("active"));
}

#[test]
fn resolve_subscription_state_ignores_provider_event_fallback_on_equal_timestamp() {
    let existing = ExistingSubscriptionState {
        subscription_status: Some("active".into()),
        subscription_current_period_end_at: None,
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_400_000, 0),
    };
    let incoming = IncomingSubscriptionState {
        subscription_status: Some("past_due".into()),
        subscription_current_period_end_at: None,
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_400_000, 0),
        source: Some(SubscriptionStatusSource::ProviderDerived),
        provider_confidence: Some(ProviderStatusConfidence::EventFallback),
    };
    let resolved = resolve_subscription_state(Some(existing.clone()), incoming);
    assert_eq!(resolved.subscription_status, existing.subscription_status);
}

#[test]
fn resolve_subscription_state_accepts_provider_direct_field_on_equal_timestamp() {
    let existing = ExistingSubscriptionState {
        subscription_status: Some("active".into()),
        subscription_current_period_end_at: None,
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_500_000, 0),
    };
    let incoming = IncomingSubscriptionState {
        subscription_status: Some("past_due".into()),
        subscription_current_period_end_at: None,
        subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_500_000, 0),
        source: Some(SubscriptionStatusSource::ProviderDerived),
        provider_confidence: Some(ProviderStatusConfidence::DirectField),
    };
    let resolved = resolve_subscription_state(Some(existing), incoming);
    assert_eq!(resolved.subscription_status.as_deref(), Some("past_due"));
}

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
fn parse_subscription_period_end_accepts_unix_timestamp() {
    let v = json!({ "subscription_current_period_end": 1_700_000_000_i64 });
    let got = parse_subscription_period_end(&v).expect("timestamp should parse");
    assert_eq!(got.timestamp(), 1_700_000_000_i64);
}

#[test]
fn parse_subscription_period_end_accepts_rfc3339() {
    let v = json!({ "subscription_current_period_end": "2026-04-06T12:34:56Z" });
    let got = parse_subscription_period_end(&v).expect("rfc3339 should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-06T12:34:56+00:00");
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
fn parse_subscription_status_updated_at_accepts_unix_timestamp() {
    let v = json!({ "subscription_status_updated_at": 1_700_123_456_i64 });
    let got = parse_subscription_status_updated_at(&v).expect("timestamp should parse");
    assert_eq!(got.timestamp(), 1_700_123_456_i64);
}

#[test]
fn parse_subscription_status_updated_at_accepts_rfc3339() {
    let v = json!({ "subscription_status_updated_at": "2026-04-06T20:30:40Z" });
    let got = parse_subscription_status_updated_at(&v).expect("rfc3339 should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-06T20:30:40+00:00");
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
fn parse_event_created_at_accepts_paddle_occurred_at_rfc3339() {
    let v = json!({
        "billing_provider": "paddle",
        "occurred_at": "2026-04-07T08:09:10Z"
    });
    let got = parse_event_created_at(&v).expect("occurred_at should parse");
    assert_eq!(got.to_rfc3339(), "2026-04-07T08:09:10+00:00");
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
