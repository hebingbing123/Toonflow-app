use chrono::{DateTime, Utc};
use serde_json::json;

use crate::billing::provider_rules::ProviderStatusConfidence;

use super::super::subscription_state::{
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
fn parse_subscription_status_rejects_unknown_value() {
    let v = json!({ "subscription_status": "paused" });
    assert!(parse_subscription_status(&v).is_none());
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
