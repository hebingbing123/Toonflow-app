use serde_json::{json, Value};

use super::super::*;

#[test]
fn derive_stripe_trial_will_end_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.trial_will_end"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_pending_update_applied_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.pending_update_applied"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_pending_update_expired_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.pending_update_expired"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_pending_update_created_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.pending_update_created"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_invoice_finalization_failed_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.finalization_failed"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_invoice_upcoming_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.upcoming"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_invoice_created_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.created"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_invoice_finalized_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.finalized"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_invoice_updated_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.updated"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_invoice_sent_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.sent"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_payment_intent_succeeded_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "payment_intent.succeeded"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_charge_failed_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "charge.failed"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_payment_intent_requires_action_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "payment_intent.requires_action"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}

#[test]
fn derive_stripe_charge_dispute_created_does_not_change_subscription_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "charge.dispute.created"
    });
    assert!(stripe::is_informational_event(
        v.get("type").and_then(Value::as_str).map(str::trim)
    ));
    let d = derive_from_provider(&v);
    assert!(d.subscription_status.is_none());
    assert!(d.status_confidence.is_none());
}
