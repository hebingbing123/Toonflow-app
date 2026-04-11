//! Subscription field parsing and merge rules for webhook-driven profile updates.

use chrono::{DateTime, Utc};
use serde_json::Value;

use crate::billing::provider_rules::ProviderStatusConfidence;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum SubscriptionStatusSource {
    Explicit,
    ProviderDerived,
}

#[derive(Debug, Clone)]
pub(super) struct ExistingSubscriptionState {
    pub(super) subscription_status: Option<String>,
    pub(super) subscription_current_period_end_at: Option<DateTime<Utc>>,
    pub(super) subscription_status_updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone)]
pub(super) struct IncomingSubscriptionState {
    pub(super) subscription_status: Option<String>,
    pub(super) subscription_current_period_end_at: Option<DateTime<Utc>>,
    pub(super) subscription_status_updated_at: Option<DateTime<Utc>>,
    pub(super) source: Option<SubscriptionStatusSource>,
    pub(super) provider_confidence: Option<ProviderStatusConfidence>,
}

#[derive(Debug, Clone)]
pub(super) struct ResolvedSubscriptionState {
    pub(super) subscription_status: Option<String>,
    pub(super) subscription_current_period_end_at: Option<DateTime<Utc>>,
    pub(super) subscription_status_updated_at: Option<DateTime<Utc>>,
}

pub(super) fn normalize_subscription_status(raw: &str) -> Option<String> {
    let status = raw.trim().to_ascii_lowercase();
    match status.as_str() {
        "free" | "trialing" | "active" | "past_due" | "unpaid" | "canceled" | "incomplete"
        | "incomplete_expired" => Some(status),
        _ => None,
    }
}

pub(super) fn parse_subscription_status(v: &Value) -> Option<String> {
    let raw = v.get("subscription_status").and_then(Value::as_str)?;
    normalize_subscription_status(raw)
}

pub(super) fn parse_subscription_period_end(v: &Value) -> Option<DateTime<Utc>> {
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

pub(super) fn parse_subscription_status_updated_at(v: &Value) -> Option<DateTime<Utc>> {
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

fn is_terminal_subscription_status(status: &str) -> bool {
    matches!(status, "canceled" | "unpaid" | "incomplete_expired")
}

pub(super) fn resolve_subscription_state(
    existing: Option<ExistingSubscriptionState>,
    incoming: IncomingSubscriptionState,
) -> ResolvedSubscriptionState {
    let Some(existing) = existing else {
        return ResolvedSubscriptionState {
            subscription_status: incoming.subscription_status,
            subscription_current_period_end_at: incoming.subscription_current_period_end_at,
            subscription_status_updated_at: incoming.subscription_status_updated_at,
        };
    };

    let Some(incoming_status) = incoming.subscription_status.clone() else {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    };

    let Some(incoming_updated_at) = incoming.subscription_status_updated_at else {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    };

    let Some(existing_updated_at) = existing.subscription_status_updated_at else {
        return ResolvedSubscriptionState {
            subscription_status: Some(incoming_status),
            subscription_current_period_end_at: incoming.subscription_current_period_end_at,
            subscription_status_updated_at: Some(incoming_updated_at),
        };
    };

    if incoming_updated_at < existing_updated_at {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    }

    // Guard: provider-derived events should not reopen terminal states without an explicit status payload.
    let terminal_regression = matches!(
        (
            existing.subscription_status.as_deref(),
            incoming.source,
            incoming_status.as_str(),
        ),
        (Some(curr), Some(SubscriptionStatusSource::ProviderDerived), next)
            if is_terminal_subscription_status(curr) && !is_terminal_subscription_status(next)
    );
    if terminal_regression {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    }

    // Guard: when timestamp ties exactly, low-confidence provider fallback events should not
    // churn existing state (e.g. duplicate/reordered "event type only" notifications).
    let low_confidence_tie_override = matches!(
        (
            incoming.source,
            incoming.provider_confidence,
            existing.subscription_status.as_deref(),
            incoming_status.as_str(),
        ),
        (
            Some(SubscriptionStatusSource::ProviderDerived),
            Some(ProviderStatusConfidence::EventFallback),
            Some(curr),
            next
        ) if curr != next && incoming_updated_at == existing_updated_at
    );
    if low_confidence_tie_override {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    }

    ResolvedSubscriptionState {
        subscription_status: Some(incoming_status),
        subscription_current_period_end_at: incoming.subscription_current_period_end_at,
        subscription_status_updated_at: Some(incoming_updated_at),
    }
}
