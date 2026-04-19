use serde_json::{json, Value};

use super::super::*;

#[test]
fn derive_paddle_maps_transaction_canceled_to_canceled() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "transaction.canceled"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("canceled"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_paddle_maps_subscription_paused_to_past_due() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "subscription.paused"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("past_due"));
}

#[test]
fn derive_paddle_maps_subscription_expired_to_canceled() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "subscription.expired"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("canceled"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_paddle_trialing_event_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "subscription.trialing"
    });
    assert!(paddle::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_paddle_transaction_billed_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "transaction.billed"
    });
    assert!(paddle::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_paddle_transaction_created_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "transaction.created"
    });
    assert!(paddle::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_paddle_transaction_updated_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "transaction.updated"
    });
    assert!(paddle::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_paddle_transaction_ready_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "transaction.ready"
    });
    assert!(paddle::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_paddle_transaction_paid_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "transaction.paid"
    });
    assert!(paddle::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}
