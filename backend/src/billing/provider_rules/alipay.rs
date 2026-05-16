use serde_json::Value;

use super::{
    event_type_from_payload, parse_event_datetime, status_from_event_mappings, EventStatusMapping,
    ProviderDerivedFields, ProviderStatusConfidence,
};

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

pub(super) fn is_informational_event(event_type: Option<&str>) -> bool {
    let Some(event_type) = event_type else {
        return false;
    };
    ALIPAY_INFORMATIONAL_EVENTS.contains(&event_type)
}

fn alipay_status_from_trade_status(trade_status: &str) -> Option<&'static str> {
    match trade_status.trim().to_ascii_uppercase().as_str() {
        "TRADE_SUCCESS" | "TRADE_FINISHED" => Some("active"),
        "TRADE_CLOSED" => Some("canceled"),
        "WAIT_BUYER_PAY" => Some("incomplete"),
        _ => None,
    }
}

pub(super) fn derive(v: &Value) -> ProviderDerivedFields {
    let event_type = event_type_from_payload(v);
    if is_informational_event(event_type) {
        return ProviderDerivedFields::default();
    }
    let fallback_status = status_from_event_mappings(event_type, ALIPAY_EVENT_STATUS_MAPPINGS);
    let subscription_status = v
        .get("trade_status")
        .and_then(Value::as_str)
        .and_then(alipay_status_from_trade_status)
        .map(ToOwned::to_owned)
        .or_else(|| fallback_status.map(ToOwned::to_owned));

    let subscription_status_updated_at = parse_event_datetime(v, "notify_time")
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
