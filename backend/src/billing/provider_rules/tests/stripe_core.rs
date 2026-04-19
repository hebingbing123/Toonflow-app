use serde_json::json;

use super::super::*;

#[test]
fn status_from_event_mappings_returns_known_mapping() {
    let got = stripe::status_from_event_type_for_tests(Some("invoice.payment_succeeded"));
    assert_eq!(got, Some("active"));
}

#[test]
fn derive_stripe_prefers_object_status() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.deleted",
        "data": { "object": { "status": "past_due" } }
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("past_due"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::DirectField)
    );
}

#[test]
fn normalize_webhook_lowercases_provider_name() {
    let v = json!({
        "billing_provider": " Stripe ",
        "type": "invoice.payment_succeeded"
    });
    let n = normalize_webhook(&v);
    assert_eq!(n.provider.as_deref(), Some("stripe"));
}

#[test]
fn derive_paddle_prefers_data_status() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "subscription.canceled",
        "data": { "status": "active" }
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("active"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::DirectField)
    );
}

#[test]
fn derive_paddle_falls_back_to_event_mapping() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "transaction.payment_failed"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("past_due"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_paddle_parses_occurred_at_and_next_billed_at() {
    let v = json!({
        "billing_provider": "paddle",
        "type": "subscription.updated",
        "occurred_at": "2026-04-07T08:09:10Z",
        "data": {
            "next_billed_at": "2026-05-01T00:00:00Z"
        }
    });
    let d = derive_from_provider(&v);
    assert_eq!(
        d.subscription_status_updated_at
            .expect("occurred_at should parse")
            .to_rfc3339(),
        "2026-04-07T08:09:10+00:00"
    );
    assert_eq!(
        d.subscription_current_period_end
            .expect("next_billed_at should parse")
            .to_rfc3339(),
        "2026-05-01T00:00:00+00:00"
    );
}

#[test]
fn derive_stripe_maps_marked_uncollectible_to_unpaid() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.marked_uncollectible"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("unpaid"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_stripe_maps_invoice_paid_to_active() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.paid"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("active"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_stripe_maps_invoice_overdue_to_past_due() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.overdue"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("past_due"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_stripe_maps_invoice_payment_reversal_to_past_due() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "invoice.payment_reversal"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("past_due"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}

#[test]
fn derive_stripe_maps_subscription_resumed_to_active() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.resumed"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("active"));
}

#[test]
fn derive_stripe_maps_subscription_unpaused_to_active() {
    let v = json!({
        "billing_provider": "stripe",
        "type": "customer.subscription.unpaused"
    });
    let d = derive_from_provider(&v);
    assert_eq!(d.subscription_status.as_deref(), Some("active"));
    assert_eq!(
        d.status_confidence,
        Some(ProviderStatusConfidence::EventFallback)
    );
}
