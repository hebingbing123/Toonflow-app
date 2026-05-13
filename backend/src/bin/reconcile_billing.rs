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
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;

/// Billing state mismatch detected during reconciliation.
#[derive(Debug, Clone)]
struct BillingMismatch {
    user_id: Uuid,
    workspace_id: Uuid,
    field: String,
    user_value: Option<String>,
    workspace_value: Option<String>,
}

/// Run reconciliation for all users with personal workspaces.
async fn reconcile_all_personal_workspaces(pool: &sqlx::PgPool) -> Result<usize, sqlx::Error> {
    let user_ids: Vec<(Uuid,)> = sqlx::query_as(
        r#"
        SELECT DISTINCT u.user_id
        FROM app_user_profile u
        INNER JOIN app_workspace w ON w.owner_user_id = u.user_id
        WHERE w.workspace_type = 'personal'
        "#,
    )
    .fetch_all(pool)
    .await?;

    let mut total_mismatches = 0;
    let total_users = user_ids.len();

    for (user_id,) in user_ids {
        let mismatches = check_personal_workspace_billing_consistency(pool, user_id).await?;

        for mismatch in &mismatches {
            tracing::warn!(
                user_id = %mismatch.user_id,
                workspace_id = %mismatch.workspace_id,
                field = %mismatch.field,
                user_value = ?mismatch.user_value,
                workspace_value = ?mismatch.workspace_value,
                "Billing reconciliation mismatch detected"
            );
        }

        total_mismatches += mismatches.len();
    }

    if total_mismatches > 0 {
        tracing::warn!(
            total_mismatches = total_mismatches,
            total_users_checked = total_users,
            "Billing reconciliation completed with mismatches"
        );
    } else {
        tracing::info!(
            total_users_checked = total_users,
            "Billing reconciliation completed: no mismatches found"
        );
    }

    Ok(total_mismatches)
}

/// Compare billing state for a user's personal workspace.
#[allow(clippy::type_complexity)]
async fn check_personal_workspace_billing_consistency(
    pool: &sqlx::PgPool,
    user_id: Uuid,
) -> Result<Vec<BillingMismatch>, sqlx::Error> {
    let row: Option<(
        Uuid,
        Option<String>,
        Option<String>,
        Option<String>,
        Option<String>,
        Option<String>,
        Option<String>,
    )> = sqlx::query_as(
        r#"
        SELECT
          w.id AS workspace_id,
          u.plan_tier AS user_plan_tier,
          w.plan_tier AS workspace_plan_tier,
          u.billing_currency AS user_billing_currency,
          w.billing_currency AS workspace_billing_currency,
          u.billing_provider AS user_billing_provider,
          w.billing_provider AS workspace_billing_provider
        FROM app_user_profile u
        INNER JOIN app_workspace w ON w.owner_user_id = u.user_id
        WHERE u.user_id = $1
          AND w.workspace_type = 'personal'
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    let Some((
        workspace_id,
        user_plan_tier,
        workspace_plan_tier,
        user_billing_currency,
        workspace_billing_currency,
        user_billing_provider,
        workspace_billing_provider,
    )) = row
    else {
        return Ok(Vec::new());
    };

    let mut mismatches = Vec::new();

    if user_plan_tier != workspace_plan_tier {
        mismatches.push(BillingMismatch {
            user_id,
            workspace_id,
            field: "plan_tier".to_string(),
            user_value: user_plan_tier,
            workspace_value: workspace_plan_tier,
        });
    }

    if user_billing_currency != workspace_billing_currency {
        mismatches.push(BillingMismatch {
            user_id,
            workspace_id,
            field: "billing_currency".to_string(),
            user_value: user_billing_currency,
            workspace_value: workspace_billing_currency,
        });
    }

    if user_billing_provider != workspace_billing_provider {
        mismatches.push(BillingMismatch {
            user_id,
            workspace_id,
            field: "billing_provider".to_string(),
            user_value: user_billing_provider,
            workspace_value: workspace_billing_provider,
        });
    }

    Ok(mismatches)
}

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
