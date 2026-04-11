use super::*;
use serde_json::json;

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
