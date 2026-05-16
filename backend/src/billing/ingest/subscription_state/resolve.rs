use crate::billing::provider_rules::ProviderStatusConfidence;

use super::types::{
    ExistingSubscriptionState, IncomingSubscriptionState, ResolvedSubscriptionState,
    SubscriptionStatusSource,
};

fn is_terminal_subscription_status(status: &str) -> bool {
    matches!(status, "canceled" | "unpaid" | "incomplete_expired")
}

pub(in crate::billing::ingest) fn resolve_subscription_state(
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
