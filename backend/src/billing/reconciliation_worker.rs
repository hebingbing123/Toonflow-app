//! Billing reconciliation worker: nightly job comparing user vs workspace billing state.
//!
//! **Task 4.3**: Reconciliation hook (metric or nightly job) comparing legacy vs
//! workspace-derived state during shadow period.
//!
//! This worker runs periodically (default: every 24 hours) to detect mismatches
//! between user-scope and workspace-scope billing data.

use std::time::Duration;
use tokio::time::interval;

use crate::state::AppState;

/// Run the reconciliation worker loop.
///
/// Checks billing consistency every 24 hours (configurable via RECONCILIATION_INTERVAL_HOURS).
pub async fn run(state: AppState) {
    let interval_hours = std::env::var("RECONCILIATION_INTERVAL_HOURS")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(24);

    let interval_duration = Duration::from_secs(interval_hours * 3600);
    let mut ticker = interval(interval_duration);

    tracing::info!(
        interval_hours = interval_hours,
        "Billing reconciliation worker started"
    );

    loop {
        ticker.tick().await;

        tracing::info!("Starting billing reconciliation check");

        match run_reconciliation_check(&state).await {
            Ok(mismatch_count) => {
                if mismatch_count > 0 {
                    tracing::warn!(
                        mismatch_count = mismatch_count,
                        "Billing reconciliation completed with mismatches"
                    );
                } else {
                    tracing::info!("Billing reconciliation completed: no mismatches found");
                }
            }
            Err(e) => {
                tracing::error!(
                    error = %e,
                    "Billing reconciliation check failed"
                );
            }
        }
    }
}

/// Run a single reconciliation check.
///
/// Returns the number of mismatches found.
async fn run_reconciliation_check(state: &AppState) -> Result<usize, String> {
    let pool = state
        .require_pool()
        .map_err(|e| format!("Database not configured: {:?}", e))?;

    let mismatch_count = super::reconcile_all_personal_workspaces(pool)
        .await
        .map_err(|e| format!("Reconciliation query failed: {}", e))?;

    Ok(mismatch_count)
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_interval_parsing() {
        // Test default
        std::env::remove_var("RECONCILIATION_INTERVAL_HOURS");
        let interval_hours = std::env::var("RECONCILIATION_INTERVAL_HOURS")
            .ok()
            .and_then(|s| s.parse::<u64>().ok())
            .unwrap_or(24);
        assert_eq!(interval_hours, 24);

        // Test custom value
        std::env::set_var("RECONCILIATION_INTERVAL_HOURS", "12");
        let interval_hours = std::env::var("RECONCILIATION_INTERVAL_HOURS")
            .ok()
            .and_then(|s| s.parse::<u64>().ok())
            .unwrap_or(24);
        assert_eq!(interval_hours, 12);
        std::env::remove_var("RECONCILIATION_INTERVAL_HOURS");
    }
}
