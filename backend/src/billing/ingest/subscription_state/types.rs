use chrono::{DateTime, Utc};

use crate::billing::provider_rules::ProviderStatusConfidence;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(in crate::billing::ingest) enum SubscriptionStatusSource {
    Explicit,
    ProviderDerived,
}

#[derive(Debug, Clone)]
pub(in crate::billing::ingest) struct ExistingSubscriptionState {
    pub subscription_status: Option<String>,
    pub subscription_current_period_end_at: Option<DateTime<Utc>>,
    pub subscription_status_updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone)]
pub(in crate::billing::ingest) struct IncomingSubscriptionState {
    pub subscription_status: Option<String>,
    pub subscription_current_period_end_at: Option<DateTime<Utc>>,
    pub subscription_status_updated_at: Option<DateTime<Utc>>,
    pub source: Option<SubscriptionStatusSource>,
    pub provider_confidence: Option<ProviderStatusConfidence>,
}

#[derive(Debug, Clone)]
pub(in crate::billing::ingest) struct ResolvedSubscriptionState {
    pub subscription_status: Option<String>,
    pub subscription_current_period_end_at: Option<DateTime<Utc>>,
    pub subscription_status_updated_at: Option<DateTime<Utc>>,
}
