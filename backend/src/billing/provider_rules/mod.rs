use chrono::{DateTime, NaiveDateTime, Utc};
use serde_json::Value;

use super::provider_adapter::select_billing_adapter;

mod alipay;
mod paddle;
mod stripe;

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

#[derive(Debug, Default)]
pub(crate) struct NormalizedWebhook {
    pub(crate) provider: Option<String>,
    pub(crate) derived: ProviderDerivedFields,
}

pub(super) struct EventStatusMapping {
    pub(super) event_type: &'static str,
    pub(super) status: &'static str,
}

pub(crate) fn normalize_provider_name(raw: &str) -> Option<String> {
    let v = raw.trim().to_ascii_lowercase();
    if v.is_empty() {
        None
    } else {
        Some(v.chars().take(64).collect())
    }
}

fn billing_provider_from_name(provider: Option<&str>) -> BillingProvider {
    match provider {
        Some("stripe") => BillingProvider::Stripe,
        Some("alipay") => BillingProvider::Alipay,
        Some("paddle") => BillingProvider::Paddle,
        _ => BillingProvider::Unknown,
    }
}

pub(super) fn normalize_subscription_status(raw: &str) -> Option<String> {
    let status = raw.trim().to_ascii_lowercase();
    match status.as_str() {
        "free" | "trialing" | "active" | "past_due" | "unpaid" | "canceled" | "incomplete"
        | "incomplete_expired" => Some(status),
        _ => None,
    }
}

pub(super) fn status_from_event_mappings(
    event_type: Option<&str>,
    mappings: &[EventStatusMapping],
) -> Option<&'static str> {
    let event_type = event_type?;
    mappings
        .iter()
        .find(|m| m.event_type == event_type)
        .map(|m| m.status)
}

pub(super) fn event_type_from_payload(v: &Value) -> Option<&str> {
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
        return unix_timestamp_to_utc(ts);
    }
    NaiveDateTime::parse_from_str(raw, "%Y-%m-%d %H:%M:%S")
        .ok()
        .map(|ndt| ndt.and_utc())
}

pub(super) fn unix_timestamp_to_utc(ts: i64) -> Option<DateTime<Utc>> {
    // Accept both seconds and milliseconds (common in webhook payloads).
    if ts.abs() >= 1_000_000_000_000 {
        DateTime::<Utc>::from_timestamp_millis(ts)
    } else {
        DateTime::<Utc>::from_timestamp(ts, 0)
    }
}

pub(super) fn parse_event_datetime(v: &Value, key: &str) -> Option<DateTime<Utc>> {
    if let Some(ts) = v.get(key).and_then(Value::as_i64) {
        return unix_timestamp_to_utc(ts);
    }
    v.get(key)
        .and_then(Value::as_str)
        .and_then(parse_timestamp_string)
}

pub(crate) fn is_informational_event(v: &Value) -> bool {
    let event_type = event_type_from_payload(v);
    let selected = select_billing_adapter(v);
    match billing_provider_from_name(selected.mapping_provider.as_deref()) {
        BillingProvider::Stripe => stripe::is_informational_event(event_type),
        BillingProvider::Alipay => alipay::is_informational_event(event_type),
        BillingProvider::Paddle => paddle::is_informational_event(event_type),
        BillingProvider::Unknown => false,
    }
}

pub(crate) fn derive_from_provider(v: &Value) -> ProviderDerivedFields {
    let selected = select_billing_adapter(v);
    match billing_provider_from_name(selected.mapping_provider.as_deref()) {
        BillingProvider::Stripe => stripe::derive(v),
        BillingProvider::Alipay => alipay::derive(v),
        BillingProvider::Paddle => paddle::derive(v),
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
mod tests;
