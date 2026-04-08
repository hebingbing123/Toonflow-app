use chrono::{DateTime, NaiveDateTime, Utc};
use serde_json::Value;

use super::provider_adapter::select_billing_adapter;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum BillingProvider {
    Stripe,
    Alipay,
    Paddle,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ProviderStatusConfidence {
    DirectField,
    EventFallback,
}

#[derive(Debug, Default)]
pub(crate) struct ProviderDerivedFields {
    pub(crate) subscription_status: Option<String>,
    pub(crate) subscription_current_period_end: Option<DateTime<Utc>>,
    pub(crate) subscription_status_updated_at: Option<DateTime<Utc>>,
    pub(crate) status_confidence: Option<ProviderStatusConfidence>,
}

struct EventStatusMapping {
    event_type: &'static str,
    status: &'static str,
}

const STRIPE_EVENT_STATUS_MAPPINGS: &[EventStatusMapping] = &[
    EventStatusMapping {
        event_type: "customer.subscription.created",
        status: "trialing",
    },
    EventStatusMapping {
        event_type: "customer.subscription.updated",
        status: "active",
    },
    EventStatusMapping {
        event_type: "customer.subscription.paused",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "customer.subscription.resumed",
        status: "active",
    },
    EventStatusMapping {
        event_type: "customer.subscription.unpaused",
        status: "active",
    },
    EventStatusMapping {
        event_type: "customer.subscription.deleted",
        status: "canceled",
    },
    EventStatusMapping {
        event_type: "invoice.payment_action_required",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "invoice.payment_failed",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "invoice.payment_reversal",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "invoice.overdue",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "invoice.payment_succeeded",
        status: "active",
    },
    EventStatusMapping {
        event_type: "invoice.paid",
        status: "active",
    },
    EventStatusMapping {
        event_type: "invoice.marked_uncollectible",
        status: "unpaid",
    },
    EventStatusMapping {
        event_type: "invoice.voided",
        status: "canceled",
    },
];

/// Stripe events that are intentionally informational-only in current webhook state machine.
/// These events should not drive subscription status transitions by event fallback.
const STRIPE_INFORMATIONAL_EVENTS: &[&str] = &[
    "customer.subscription.trial_will_end",
    "customer.subscription.pending_update_applied",
    "customer.subscription.pending_update_expired",
    "customer.subscription.pending_update_created",
    "invoice.finalization_failed",
    "invoice.upcoming",
    "invoice.created",
    "invoice.finalized",
    "invoice.updated",
    "invoice.sent",
    "payment_intent.created",
    "payment_intent.succeeded",
    "payment_intent.payment_failed",
    "payment_intent.canceled",
    "payment_intent.processing",
    "payment_intent.requires_action",
    "charge.succeeded",
    "charge.updated",
    "charge.failed",
    "charge.captured",
    "charge.refunded",
    "charge.refund.updated",
    "charge.dispute.created",
    "charge.dispute.updated",
    "charge.dispute.closed",
];

const ALIPAY_EVENT_STATUS_MAPPINGS: &[EventStatusMapping] = &[
    EventStatusMapping {
        event_type: "trade.success",
        status: "active",
    },
    EventStatusMapping {
        event_type: "trade.closed",
        status: "canceled",
    },
    EventStatusMapping {
        event_type: "trade.wait_buyer_pay",
        status: "incomplete",
    },
];

/// Alipay events that are informational-only for current subscription status state machine.
const ALIPAY_INFORMATIONAL_EVENTS: &[&str] = &["trade.finished"];

const PADDLE_EVENT_STATUS_MAPPINGS: &[EventStatusMapping] = &[
    EventStatusMapping {
        event_type: "subscription.created",
        status: "trialing",
    },
    EventStatusMapping {
        event_type: "subscription.activated",
        status: "active",
    },
    EventStatusMapping {
        event_type: "subscription.updated",
        status: "active",
    },
    EventStatusMapping {
        event_type: "subscription.paused",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "subscription.resumed",
        status: "active",
    },
    EventStatusMapping {
        event_type: "subscription.canceled",
        status: "canceled",
    },
    EventStatusMapping {
        event_type: "subscription.expired",
        status: "canceled",
    },
    EventStatusMapping {
        event_type: "subscription.past_due",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "transaction.completed",
        status: "active",
    },
    EventStatusMapping {
        event_type: "transaction.payment_failed",
        status: "past_due",
    },
    EventStatusMapping {
        event_type: "transaction.canceled",
        status: "canceled",
    },
];

/// Paddle events that are informational-only for current subscription status state machine.
const PADDLE_INFORMATIONAL_EVENTS: &[&str] = &[
    "subscription.trialing",
    "transaction.billed",
    "transaction.created",
    "transaction.updated",
    "transaction.paid",
    "transaction.ready",
];

pub(crate) fn normalize_provider_name(raw: &str) -> Option<String> {
    let v = raw.trim().to_ascii_lowercase();
    if v.is_empty() {
        None
    } else {
        Some(v.chars().take(64).collect())
    }
}

#[derive(Debug, Default)]
pub(crate) struct NormalizedWebhook {
    pub(crate) provider: Option<String>,
    pub(crate) derived: ProviderDerivedFields,
}

fn billing_provider_from_name(provider: Option<&str>) -> BillingProvider {
    match provider {
        Some("stripe") => BillingProvider::Stripe,
        Some("alipay") => BillingProvider::Alipay,
        Some("paddle") => BillingProvider::Paddle,
        _ => BillingProvider::Unknown,
    }
}

fn normalize_subscription_status(raw: &str) -> Option<String> {
    let status = raw.trim().to_ascii_lowercase();
    match status.as_str() {
        "free" | "trialing" | "active" | "past_due" | "unpaid" | "canceled" | "incomplete"
        | "incomplete_expired" => Some(status),
        _ => None,
    }
}

fn status_from_event_mappings(
    event_type: Option<&str>,
    mappings: &[EventStatusMapping],
) -> Option<&'static str> {
    let event_type = event_type?;
    mappings
        .iter()
        .find(|m| m.event_type == event_type)
        .map(|m| m.status)
}

fn event_type_from_payload(v: &Value) -> Option<&str> {
    for key in ["type", "event_type", "event", "name", "notify_type"] {
        if let Some(event_type) = v
            .get(key)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|s| !s.is_empty())
        {
            return Some(event_type);
        }
    }
    None
}

fn parse_timestamp_string(raw: &str) -> Option<DateTime<Utc>> {
    let raw = raw.trim();
    if raw.is_empty() {
        return None;
    }
    if let Ok(dt) = DateTime::parse_from_rfc3339(raw) {
        return Some(dt.with_timezone(&Utc));
    }
    if let Ok(ts) = raw.parse::<i64>() {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }
    NaiveDateTime::parse_from_str(raw, "%Y-%m-%d %H:%M:%S")
        .ok()
        .map(|ndt| ndt.and_utc())
}

fn parse_event_datetime(v: &Value, key: &str) -> Option<DateTime<Utc>> {
    if let Some(ts) = v.get(key).and_then(Value::as_i64) {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }
    v.get(key)
        .and_then(Value::as_str)
        .and_then(parse_timestamp_string)
}

fn is_stripe_informational_event(event_type: Option<&str>) -> bool {
    let Some(event_type) = event_type else {
        return false;
    };
    STRIPE_INFORMATIONAL_EVENTS.contains(&event_type)
}

fn is_alipay_informational_event(event_type: Option<&str>) -> bool {
    let Some(event_type) = event_type else {
        return false;
    };
    ALIPAY_INFORMATIONAL_EVENTS.contains(&event_type)
}

fn is_paddle_informational_event(event_type: Option<&str>) -> bool {
    let Some(event_type) = event_type else {
        return false;
    };
    PADDLE_INFORMATIONAL_EVENTS.contains(&event_type)
}

fn derive_from_stripe(v: &Value) -> ProviderDerivedFields {
    let event_type = event_type_from_payload(v);
    if is_stripe_informational_event(event_type) {
        return ProviderDerivedFields::default();
    }
    let fallback_status = status_from_event_mappings(event_type, STRIPE_EVENT_STATUS_MAPPINGS);
    let subscription_status = v
        .pointer("/data/object/status")
        .and_then(Value::as_str)
        .and_then(normalize_subscription_status)
        .or_else(|| fallback_status.map(ToOwned::to_owned));

    let subscription_status_updated_at = v
        .get("created")
        .and_then(Value::as_i64)
        .and_then(|ts| DateTime::<Utc>::from_timestamp(ts, 0));

    let subscription_current_period_end = v
        .pointer("/data/object/current_period_end")
        .and_then(Value::as_i64)
        .and_then(|ts| DateTime::<Utc>::from_timestamp(ts, 0));

    ProviderDerivedFields {
        subscription_status,
        subscription_current_period_end,
        subscription_status_updated_at,
        status_confidence: if v
            .pointer("/data/object/status")
            .and_then(Value::as_str)
            .is_some()
        {
            Some(ProviderStatusConfidence::DirectField)
        } else if fallback_status.is_some() {
            Some(ProviderStatusConfidence::EventFallback)
        } else {
            None
        },
    }
}

fn alipay_status_from_trade_status(trade_status: &str) -> Option<&'static str> {
    match trade_status.trim().to_ascii_uppercase().as_str() {
        "TRADE_SUCCESS" | "TRADE_FINISHED" => Some("active"),
        "TRADE_CLOSED" => Some("canceled"),
        "WAIT_BUYER_PAY" => Some("incomplete"),
        _ => None,
    }
}

fn derive_from_alipay(v: &Value) -> ProviderDerivedFields {
    let event_type = event_type_from_payload(v);
    if is_alipay_informational_event(event_type) {
        return ProviderDerivedFields::default();
    }
    let fallback_status = status_from_event_mappings(event_type, ALIPAY_EVENT_STATUS_MAPPINGS);
    let subscription_status = v
        .get("trade_status")
        .and_then(Value::as_str)
        .and_then(alipay_status_from_trade_status)
        .map(ToOwned::to_owned)
        .or_else(|| fallback_status.map(ToOwned::to_owned));

    let subscription_status_updated_at = v
        .get("notify_time")
        .and_then(Value::as_i64)
        .and_then(|ts| DateTime::<Utc>::from_timestamp(ts, 0))
        .or_else(|| parse_event_datetime(v, "notify_time"))
        .or_else(|| parse_event_datetime(v, "gmt_payment"))
        .or_else(|| parse_event_datetime(v, "gmt_create"))
        .or_else(|| parse_event_datetime(v, "gmt_close"));

    ProviderDerivedFields {
        subscription_status,
        subscription_current_period_end: None,
        subscription_status_updated_at,
        status_confidence: if v.get("trade_status").and_then(Value::as_str).is_some() {
            Some(ProviderStatusConfidence::DirectField)
        } else if fallback_status.is_some() {
            Some(ProviderStatusConfidence::EventFallback)
        } else {
            None
        },
    }
}

fn paddle_status_from_subscription_status(raw: &str) -> Option<&'static str> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "active" => Some("active"),
        "trialing" => Some("trialing"),
        "past_due" => Some("past_due"),
        "canceled" => Some("canceled"),
        "paused" => Some("past_due"),
        "unpaid" => Some("unpaid"),
        _ => None,
    }
}

fn derive_from_paddle(v: &Value) -> ProviderDerivedFields {
    let event_type = event_type_from_payload(v);
    if is_paddle_informational_event(event_type) {
        return ProviderDerivedFields::default();
    }
    let fallback_status = status_from_event_mappings(event_type, PADDLE_EVENT_STATUS_MAPPINGS);
    let subscription_status = v
        .pointer("/data/status")
        .and_then(Value::as_str)
        .and_then(paddle_status_from_subscription_status)
        .map(ToOwned::to_owned)
        .or_else(|| {
            v.pointer("/data/object/status")
                .and_then(Value::as_str)
                .and_then(paddle_status_from_subscription_status)
                .map(ToOwned::to_owned)
        })
        .or_else(|| fallback_status.map(ToOwned::to_owned));

    let subscription_current_period_end = v
        .pointer("/data/next_billed_at")
        .and_then(Value::as_str)
        .and_then(|s| DateTime::parse_from_rfc3339(s.trim()).ok())
        .map(|dt| dt.with_timezone(&Utc))
        .or_else(|| {
            v.pointer("/data/object/current_billing_period/ends_at")
                .and_then(Value::as_str)
                .and_then(|s| DateTime::parse_from_rfc3339(s.trim()).ok())
                .map(|dt| dt.with_timezone(&Utc))
        });

    let subscription_status_updated_at = v
        .get("occurred_at")
        .and_then(Value::as_str)
        .and_then(|s| DateTime::parse_from_rfc3339(s.trim()).ok())
        .map(|dt| dt.with_timezone(&Utc))
        .or_else(|| {
            v.get("occurred_at")
                .and_then(Value::as_i64)
                .and_then(|ts| DateTime::<Utc>::from_timestamp(ts, 0))
        });

    ProviderDerivedFields {
        subscription_status,
        subscription_current_period_end,
        subscription_status_updated_at,
        status_confidence: if v.pointer("/data/status").and_then(Value::as_str).is_some()
            || v.pointer("/data/object/status")
                .and_then(Value::as_str)
                .is_some()
        {
            Some(ProviderStatusConfidence::DirectField)
        } else if fallback_status.is_some() {
            Some(ProviderStatusConfidence::EventFallback)
        } else {
            None
        },
    }
}

pub(crate) fn is_informational_event(v: &Value) -> bool {
    let event_type = event_type_from_payload(v);
    let selected = select_billing_adapter(v);
    match billing_provider_from_name(selected.mapping_provider.as_deref()) {
        BillingProvider::Stripe => is_stripe_informational_event(event_type),
        BillingProvider::Alipay => is_alipay_informational_event(event_type),
        BillingProvider::Paddle => is_paddle_informational_event(event_type),
        BillingProvider::Unknown => false,
    }
}

pub(crate) fn derive_from_provider(v: &Value) -> ProviderDerivedFields {
    let selected = select_billing_adapter(v);
    match billing_provider_from_name(selected.mapping_provider.as_deref()) {
        BillingProvider::Stripe => derive_from_stripe(v),
        BillingProvider::Alipay => derive_from_alipay(v),
        BillingProvider::Paddle => derive_from_paddle(v),
        BillingProvider::Unknown => ProviderDerivedFields::default(),
    }
}

pub(crate) fn normalize_webhook(v: &Value) -> NormalizedWebhook {
    let selected = select_billing_adapter(v);
    let provider = selected.audit_provider;
    let derived = derive_from_provider(v);
    NormalizedWebhook { provider, derived }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn status_from_event_mappings_returns_known_mapping() {
        let got = status_from_event_mappings(
            Some("invoice.payment_succeeded"),
            STRIPE_EVENT_STATUS_MAPPINGS,
        );
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_stripe_informational_event(
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
        assert!(is_paddle_informational_event(
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
        assert!(is_paddle_informational_event(
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
        assert!(is_paddle_informational_event(
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
        assert!(is_paddle_informational_event(
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
        assert!(is_paddle_informational_event(
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
        assert!(is_paddle_informational_event(
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
        assert!(is_alipay_informational_event(
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
    fn derive_alipay_notify_time_accepts_legacy_datetime_format() {
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
}
