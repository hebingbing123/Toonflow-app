use chrono::{DateTime, Utc};
use serde_json::Value;

pub(in crate::billing::ingest) fn normalize_subscription_status(raw: &str) -> Option<String> {
    let status = raw.trim().to_ascii_lowercase();
    match status.as_str() {
        "free" | "trialing" | "active" | "past_due" | "unpaid" | "canceled" | "incomplete"
        | "incomplete_expired" => Some(status),
        _ => None,
    }
}

pub(in crate::billing::ingest) fn parse_subscription_status(v: &Value) -> Option<String> {
    let raw = v.get("subscription_status").and_then(Value::as_str)?;
    normalize_subscription_status(raw)
}

pub(in crate::billing::ingest) fn parse_subscription_period_end(
    v: &Value,
) -> Option<DateTime<Utc>> {
    if let Some(ts) = v
        .get("subscription_current_period_end")
        .and_then(Value::as_i64)
    {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }

    let raw = v
        .get("subscription_current_period_end")
        .and_then(Value::as_str)?;
    DateTime::parse_from_rfc3339(raw.trim())
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

pub(in crate::billing::ingest) fn parse_subscription_status_updated_at(
    v: &Value,
) -> Option<DateTime<Utc>> {
    if let Some(ts) = v
        .get("subscription_status_updated_at")
        .and_then(Value::as_i64)
    {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }

    let raw = v
        .get("subscription_status_updated_at")
        .and_then(Value::as_str)?;
    DateTime::parse_from_rfc3339(raw.trim())
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}
