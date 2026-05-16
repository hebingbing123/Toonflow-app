use crate::error::ApiError;

/// Default Stripe / Toonflow timestamp tolerance in seconds.
pub(super) const DEFAULT_STRIPE_TOLERANCE_SECS: u64 = 300;

pub(crate) fn billing_secret() -> Result<Vec<u8>, ApiError> {
    std::env::var("BILLING_WEBHOOK_SECRET")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.into_bytes())
        .ok_or(ApiError::WebhookNotConfigured)
}

pub(super) fn stripe_tolerance_secs() -> u64 {
    std::env::var("BILLING_STRIPE_TOLERANCE_SECS")
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(DEFAULT_STRIPE_TOLERANCE_SECS)
}

pub(super) fn toonflow_tolerance_secs() -> u64 {
    std::env::var("BILLING_TOONFLOW_TOLERANCE_SECS")
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(DEFAULT_STRIPE_TOLERANCE_SECS)
}

pub(super) fn now_unix_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}
