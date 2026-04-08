use chrono::{DateTime, Utc};
use serde_json::Value;

use super::{
    event_type_from_payload, normalize_subscription_status, status_from_event_mappings,
    EventStatusMapping, ProviderDerivedFields, ProviderStatusConfidence,
};

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

pub(super) fn is_informational_event(event_type: Option<&str>) -> bool {
    let Some(event_type) = event_type else {
        return false;
    };
    STRIPE_INFORMATIONAL_EVENTS.contains(&event_type)
}

pub(super) fn derive(v: &Value) -> ProviderDerivedFields {
    let event_type = event_type_from_payload(v);
    if is_informational_event(event_type) {
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

#[cfg(test)]
pub(super) fn status_from_event_type_for_tests(event_type: Option<&str>) -> Option<&'static str> {
    status_from_event_mappings(event_type, STRIPE_EVENT_STATUS_MAPPINGS)
}
