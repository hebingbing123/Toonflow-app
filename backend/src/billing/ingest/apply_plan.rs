//! `app_user_profile` upsert from normalized webhook payload.
//!
//! **Workspace-scope billing dual-write (Task 4.1)**:
//! When `workspace_id` is present in webhook payload, also upsert `app_workspace` billing columns
//! to support workspace-scope billing migration (W8.2–W8.4).

use chrono::{DateTime, Utc};
use serde_json::Value;
use uuid::Uuid;

use crate::billing::provider_adapter::select_billing_adapter;
use crate::billing::provider_rules::normalize_webhook;

use super::subscription_state::{
    parse_subscription_period_end, parse_subscription_status, parse_subscription_status_updated_at,
    resolve_subscription_state, ExistingSubscriptionState, IncomingSubscriptionState,
    SubscriptionStatusSource,
};

/// When `user_id` (UUID) and `plan_tier` (non-empty) are present, upsert profile (first successful webhook only).
pub(crate) async fn apply_plan_from_webhook_payload(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    v: &Value,
) -> Result<bool, sqlx::Error> {
    let Some(uid_str) = v.get("user_id").and_then(Value::as_str) else {
        return Ok(false);
    };
    let Ok(uid) = Uuid::parse_str(uid_str.trim()) else {
        tracing::warn!(user_id = %uid_str, "billing webhook: invalid user_id (skip profile upsert)");
        return Ok(false);
    };
    let Some(tier_raw) = v.get("plan_tier").and_then(Value::as_str) else {
        return Ok(false);
    };
    let tier: String = tier_raw.trim().chars().take(64).collect();
    if tier.is_empty() {
        return Ok(false);
    }

    let adapter = select_billing_adapter(v);
    let currency = adapter.currency;
    let normalized = normalize_webhook(v);
    let provider = normalized.provider;
    let derived = normalized.derived;
    let explicit_status = parse_subscription_status(v);
    let explicit_period_end = parse_subscription_period_end(v);
    let explicit_updated_at = parse_subscription_status_updated_at(v);
    let has_derived_status = derived.subscription_status.is_some();
    let incoming = IncomingSubscriptionState {
        subscription_status: explicit_status.clone().or(derived.subscription_status),
        subscription_current_period_end_at: explicit_period_end
            .or(derived.subscription_current_period_end),
        subscription_status_updated_at: explicit_updated_at
            .or(derived.subscription_status_updated_at),
        source: if explicit_status.is_some() {
            Some(SubscriptionStatusSource::Explicit)
        } else if has_derived_status {
            Some(SubscriptionStatusSource::ProviderDerived)
        } else {
            None
        },
        provider_confidence: derived.status_confidence,
    };

    let existing = sqlx::query_as::<_, (Option<String>, Option<DateTime<Utc>>, Option<DateTime<Utc>>)>(
        r#"
        SELECT subscription_status, subscription_current_period_end_at, subscription_status_updated_at
        FROM app_user_profile
        WHERE user_id = $1
        FOR UPDATE
        "#,
    )
    .bind(uid)
    .fetch_optional(&mut **tx)
    .await?
    .map(
        |(
            subscription_status,
            subscription_current_period_end_at,
            subscription_status_updated_at,
        )| ExistingSubscriptionState {
            subscription_status,
            subscription_current_period_end_at,
            subscription_status_updated_at,
        },
    );

    let resolved = resolve_subscription_state(existing, incoming);

    sqlx::query(
        r#"
        INSERT INTO app_user_profile (
          user_id,
          plan_tier,
          billing_currency,
          billing_provider,
          subscription_status,
          subscription_current_period_end_at,
          subscription_status_updated_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          plan_tier = EXCLUDED.plan_tier,
          billing_currency = COALESCE(EXCLUDED.billing_currency, app_user_profile.billing_currency),
          billing_provider = COALESCE(EXCLUDED.billing_provider, app_user_profile.billing_provider),
          subscription_status = EXCLUDED.subscription_status,
          subscription_current_period_end_at = EXCLUDED.subscription_current_period_end_at,
          subscription_status_updated_at = EXCLUDED.subscription_status_updated_at,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(&tier)
    .bind(currency.as_deref())
    .bind(provider.as_deref())
    .bind(resolved.subscription_status.as_deref())
    .bind(resolved.subscription_current_period_end_at)
    .bind(resolved.subscription_status_updated_at)
    .execute(&mut **tx)
    .await?;

    // Workspace-scope billing dual-write (Task 4.1)
    // If webhook includes workspace_id, also update workspace billing columns
    if let Some(workspace_id_str) = v.get("workspace_id").and_then(Value::as_str) {
        if let Ok(workspace_id) = Uuid::parse_str(workspace_id_str.trim()) {
            // Verify workspace exists and user has access (owner or member)
            let workspace_exists: Option<(Uuid,)> = sqlx::query_as(
                r#"
                SELECT w.id
                FROM app_workspace w
                LEFT JOIN app_workspace_member m ON m.workspace_id = w.id
                WHERE w.id = $1
                  AND (w.owner_user_id = $2 OR m.user_id = $2)
                "#,
            )
            .bind(workspace_id)
            .bind(uid)
            .fetch_optional(&mut **tx)
            .await?;

            if workspace_exists.is_some() {
                // Update workspace billing columns (dual-write)
                sqlx::query(
                    r#"
                    UPDATE app_workspace
                    SET
                      plan_tier = $2,
                      billing_currency = COALESCE($3, billing_currency),
                      billing_provider = COALESCE($4, billing_provider),
                      updated_at = NOW()
                    WHERE id = $1
                    "#,
                )
                .bind(workspace_id)
                .bind(&tier)
                .bind(currency.as_deref())
                .bind(provider.as_deref())
                .execute(&mut **tx)
                .await?;

                tracing::info!(
                    user_id = %uid,
                    workspace_id = %workspace_id,
                    plan_tier = %tier,
                    "Workspace billing dual-write: updated workspace billing columns"
                );
            } else {
                tracing::warn!(
                    user_id = %uid,
                    workspace_id = %workspace_id_str,
                    "Workspace billing dual-write: workspace not found or user not authorized (skipped)"
                );
            }
        } else {
            tracing::warn!(
                workspace_id = %workspace_id_str,
                "Workspace billing dual-write: invalid workspace_id format (skipped)"
            );
        }
    }

    Ok(true)
}
