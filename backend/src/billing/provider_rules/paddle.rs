use chrono::{DateTime, Utc};
use serde_json::Value;

use super::{
    event_type_from_payload, status_from_event_mappings, EventStatusMapping, ProviderDerivedFields,
    ProviderStatusConfidence,
};

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

pub(super) fn is_informational_event(event_type: Option<&str>) -> bool {
    let Some(event_type) = event_type else {
        return false;
    };
    PADDLE_INFORMATIONAL_EVENTS.contains(&event_type)
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

pub(super) fn derive(v: &Value) -> ProviderDerivedFields {
    let event_type = event_type_from_payload(v);
    if is_informational_event(event_type) {
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
