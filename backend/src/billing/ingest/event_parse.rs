use chrono::{DateTime, NaiveDateTime, Utc};
use serde_json::Value;

pub(crate) fn build_provider_event_id(provider: Option<&str>, raw_id: &str) -> String {
    let id = raw_id.trim();
    let p = provider.unwrap_or("").trim();
    if p.is_empty() {
        id.to_string()
    } else {
        format!("{p}:{id}")
    }
}

pub(super) fn parse_raw_event_id(v: &Value) -> Option<String> {
    for key in ["id", "event_id", "eventId", "notify_id", "notifyId"] {
        if let Some(id) = v
            .get(key)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|s| !s.is_empty())
        {
            return Some(id.chars().take(256).collect());
        }
        if let Some(id) = v.get(key).and_then(Value::as_i64) {
            return Some(id.to_string().chars().take(256).collect());
        }
    }
    None
}

pub(super) fn parse_event_type(v: &Value) -> Option<String> {
    for key in ["type", "event_type", "event", "name", "notify_type"] {
        if let Some(event_type) = v
            .get(key)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|s| !s.is_empty())
        {
            return Some(event_type.chars().take(128).collect());
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

fn unix_timestamp_to_utc(ts: i64) -> Option<DateTime<Utc>> {
    // Accept both seconds and milliseconds (common in webhook payloads).
    if ts.abs() >= 1_000_000_000_000 {
        DateTime::<Utc>::from_timestamp_millis(ts)
    } else {
        DateTime::<Utc>::from_timestamp(ts, 0)
    }
}

fn parse_event_datetime(v: &Value, key: &str) -> Option<DateTime<Utc>> {
    if let Some(ts) = v.get(key).and_then(Value::as_i64) {
        return unix_timestamp_to_utc(ts);
    }
    v.get(key)
        .and_then(Value::as_str)
        .and_then(parse_timestamp_string)
}

pub(super) fn parse_event_created_at(v: &Value) -> Option<DateTime<Utc>> {
    for key in [
        "event_created_at",
        "event_created",
        "created",
        "occurred_at",
        "notify_time",
        "gmt_payment",
        "gmt_create",
        "gmt_close",
        "timestamp",
    ] {
        if let Some(dt) = parse_event_datetime(v, key) {
            return Some(dt);
        }
    }
    None
}
