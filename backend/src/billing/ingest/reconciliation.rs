//! Billing reconciliation: compare user-scope vs workspace-scope billing state.
//!
//! **Task 4.3**: Reconciliation hook (metric or nightly job) comparing legacy vs
//! workspace-derived state during shadow period.
//!
//! This module provides functions to detect mismatches between:
//! - `app_user_profile` billing fields (legacy user-scope)
//! - `app_workspace` billing fields (new workspace-scope)
//!
//! Mismatches are logged and emitted as metrics for ops monitoring.

use sqlx::PgPool;
use uuid::Uuid;

/// Returns true when user and workspace billing field values are consistent.
///
/// `NULL` workspace values mean "inherit user-scope billing" per
/// `app_workspace.plan_tier` migration semantics — not a mismatch.
fn workspace_billing_field_matches_user(
    user_value: &Option<String>,
    workspace_value: &Option<String>,
) -> bool {
    match workspace_value {
        None => true,
        Some(ws) => user_value.as_deref() == Some(ws.as_str()),
    }
}

/// Billing state mismatch detected during reconciliation.
#[derive(Debug, Clone)]
pub struct BillingMismatch {
    pub user_id: Uuid,
    pub workspace_id: Uuid,
    pub field: String,
    pub user_value: Option<String>,
    pub workspace_value: Option<String>,
}

/// Compare billing state for a user's personal workspace.
///
/// Returns mismatches between user profile and workspace billing fields.
#[allow(clippy::type_complexity)]
pub async fn check_personal_workspace_billing_consistency(
    pool: &PgPool,
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
        // No personal workspace found (user may not have one yet)
        return Ok(Vec::new());
    };

    let mut mismatches = Vec::new();

    // Compare plan_tier
    if !workspace_billing_field_matches_user(&user_plan_tier, &workspace_plan_tier) {
        mismatches.push(BillingMismatch {
            user_id,
            workspace_id,
            field: "plan_tier".to_string(),
            user_value: user_plan_tier,
            workspace_value: workspace_plan_tier,
        });
    }

    // Compare billing_currency
    if !workspace_billing_field_matches_user(&user_billing_currency, &workspace_billing_currency) {
        mismatches.push(BillingMismatch {
            user_id,
            workspace_id,
            field: "billing_currency".to_string(),
            user_value: user_billing_currency,
            workspace_value: workspace_billing_currency,
        });
    }

    // Compare billing_provider
    if !workspace_billing_field_matches_user(&user_billing_provider, &workspace_billing_provider) {
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

/// Run reconciliation for all users with personal workspaces.
///
/// Returns total count of mismatches found.
/// Logs each mismatch and emits metrics.
pub async fn reconcile_all_personal_workspaces(pool: &PgPool) -> Result<usize, sqlx::Error> {
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

            // Emit metric for ops monitoring
            crate::metrics::record_billing_reconciliation_mismatch(&mismatch.field);
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn workspace_null_inherits_user_scope() {
        assert!(workspace_billing_field_matches_user(
            &Some("free".into()),
            &None,
        ));
        assert!(!workspace_billing_field_matches_user(
            &Some("free".into()),
            &Some("pro".into()),
        ));
        assert!(workspace_billing_field_matches_user(&None, &None));
    }

    #[test]
    fn test_billing_mismatch_struct() {
        let mismatch = BillingMismatch {
            user_id: Uuid::nil(),
            workspace_id: Uuid::nil(),
            field: "plan_tier".to_string(),
            user_value: Some("free".to_string()),
            workspace_value: Some("pro".to_string()),
        };

        assert_eq!(mismatch.field, "plan_tier");
        assert_eq!(mismatch.user_value, Some("free".to_string()));
        assert_eq!(mismatch.workspace_value, Some("pro".to_string()));
    }
}
