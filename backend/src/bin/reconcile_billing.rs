//! Manual billing reconciliation CLI tool.
//!
//! **Task 4.3**: Reconciliation hook for comparing legacy vs workspace-derived state.
//!
//! This CLI tool allows manual invocation of billing reconciliation checks,
//! useful for:
//! - Testing reconciliation logic before enabling the nightly worker
//! - On-demand checks during shadow period validation
//! - Debugging specific billing mismatches
//!
//! ## Usage
//!
//! ```bash
//! # Run reconciliation check
//! cargo run --bin reconcile-billing
//!
//! # With custom database URL
//! DATABASE_URL=postgresql://... cargo run --bin reconcile-billing
//! ```
//!
//! ## Output
//!
//! - Logs each mismatch found with user_id, workspace_id, field, and values
//! - Emits metrics for ops monitoring (same as nightly worker)
//! - Returns exit code 0 if successful (regardless of mismatch count)
//! - Returns exit code 1 if reconciliation check fails

use anyhow::{Context, Result};
use openflow_server::billing::reconcile_all_personal_workspaces;
use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_target(true)
        .with_level(true)
        .init();

    tracing::info!("Starting manual billing reconciliation check");

    // Get database URL from environment
    let database_url =
        std::env::var("DATABASE_URL").context("DATABASE_URL environment variable not set")?;

    // Create database connection pool
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .context("Failed to connect to database")?;

    tracing::info!("Connected to database");

    // Run reconciliation
    match reconcile_all_personal_workspaces(&pool).await {
        Ok(mismatch_count) => {
            if mismatch_count > 0 {
                tracing::warn!(
                    mismatch_count = mismatch_count,
                    "Billing reconciliation completed with mismatches"
                );
                println!("\n✗ Found {} billing mismatch(es)", mismatch_count);
                println!("  Check logs above for details");
            } else {
                tracing::info!("Billing reconciliation completed: no mismatches found");
                println!("\n✓ No billing mismatches found");
            }
            Ok(())
        }
        Err(e) => {
            tracing::error!(error = %e, "Reconciliation check failed");
            println!("\n✗ Reconciliation check failed: {}", e);
            Err(e.into())
        }
    }
}
