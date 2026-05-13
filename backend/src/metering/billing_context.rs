//! Effective billing context resolution (user vs workspace scope).
//!
//! This module implements the core billing context resolution logic per ADR:
//! - [adr-workspace-billing-attribution.md](../../../docs/plans/adr-workspace-billing-attribution.md)
//! - [adr-workspace-billing-storage-model.md](../../../docs/plans/adr-workspace-billing-storage-model.md)
//!
//! **Current production behavior**: User-scope billing (workspace-scope is gated).
//!
//! ## Resolution Logic
//!
//! 1. **Global feature flag**: If `workspace_billing_enabled = false`, always return `User` scope
//! 2. **Workspace billing data**: If workspace has `plan_tier` populated, use `Workspace` scope
//! 3. **Workspace type policy**: Enterprise workspaces may default to workspace-scope
//! 4. **Fallback**: User-scope (current production behavior)

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// Billing scope determines whether quota and plan are interpreted per user or per workspace.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BillingScope {
    /// Billing attributed to individual user (current production behavior).
    User,
    /// Billing attributed to workspace (team-level billing).
    Workspace,
}

/// Global billing configuration (typically loaded from environment or feature flags).
#[derive(Debug, Clone, Default)]
pub struct BillingConfig {
    /// Master kill-switch for workspace-scope billing.
    /// When `false`, all billing is user-scope regardless of other settings.
    pub workspace_billing_enabled: bool,

    /// Whether enterprise workspaces default to workspace-scope billing
    /// when workspace billing is enabled and workspace has no explicit plan_tier.
    pub enterprise_workspace_billing_default: bool,
}

impl BillingConfig {
    /// Load billing configuration from environment variables.
    ///
    /// Environment variables:
    /// - `WORKSPACE_BILLING_ENABLED`: Set to "true" to enable workspace-scope billing
    /// - `ENTERPRISE_WORKSPACE_BILLING_DEFAULT`: Set to "true" to default enterprise workspaces to workspace-scope
    pub fn from_env() -> Self {
        let workspace_billing_enabled = std::env::var("WORKSPACE_BILLING_ENABLED")
            .ok()
            .and_then(|s| s.trim().parse::<bool>().ok())
            .unwrap_or(false);

        let enterprise_workspace_billing_default =
            std::env::var("ENTERPRISE_WORKSPACE_BILLING_DEFAULT")
                .ok()
                .and_then(|s| s.trim().parse::<bool>().ok())
                .unwrap_or(false);

        Self {
            workspace_billing_enabled,
            enterprise_workspace_billing_default,
        }
    }
}

/// Workspace billing data (subset of app_workspace columns).
#[derive(Debug, Clone)]
struct WorkspaceBillingData {
    workspace_type: String,
    plan_tier: Option<String>,
}

/// Resolve the effective billing scope for a workspace.
///
/// ## Resolution Logic (per ADR)
///
/// 1. **Global kill-switch**: If `workspace_billing_enabled = false`, return `User`
/// 2. **Workspace-level data**: If `workspace.plan_tier IS NOT NULL`, return `Workspace`
/// 3. **Workspace type policy**: Enterprise workspaces may default to `Workspace` scope
/// 4. **Fallback**: `User` (current production behavior)
///
/// ## Arguments
///
/// - `pool`: Database connection pool
/// - `workspace_id`: Workspace to resolve billing scope for
/// - `config`: Global billing configuration
///
/// ## Returns
///
/// - `Ok(BillingScope)`: Resolved billing scope
/// - `Err(ApiError)`: Database error or workspace not found
pub async fn resolve_billing_scope(
    pool: &PgPool,
    workspace_id: Uuid,
    config: &BillingConfig,
) -> Result<BillingScope, ApiError> {
    // 1. Check global feature flag
    if !config.workspace_billing_enabled {
        return Ok(BillingScope::User);
    }

    // 2. Load workspace billing data
    let workspace_data: Option<WorkspaceBillingData> =
        sqlx::query_as::<_, (String, Option<String>)>(
            r#"
        SELECT workspace_type, plan_tier
        FROM public.app_workspace
        WHERE id = $1
        "#,
        )
        .bind(workspace_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .map(|(workspace_type, plan_tier)| WorkspaceBillingData {
            workspace_type,
            plan_tier,
        });

    let Some(workspace) = workspace_data else {
        return Err(ApiError::NotFound);
    };

    // 3. Check workspace-level override (if workspace has billing fields populated)
    if workspace.plan_tier.is_some() {
        return Ok(BillingScope::Workspace);
    }

    // 4. Default based on workspace type (product policy)
    match workspace.workspace_type.as_str() {
        "personal" => {
            // Personal workspaces default to user-scope unless explicitly migrated
            Ok(BillingScope::User)
        }
        "enterprise" => {
            // Enterprise workspaces default to workspace-scope if feature enabled
            if config.enterprise_workspace_billing_default {
                Ok(BillingScope::Workspace)
            } else {
                Ok(BillingScope::User)
            }
        }
        _ => {
            // Unknown workspace type defaults to user-scope
            Ok(BillingScope::User)
        }
    }
}

/// Effective billing context returned to callers.
///
/// Contains all information needed for quota enforcement and display.
#[derive(Debug, Clone)]
pub struct EffectiveBillingContext {
    /// Resolved billing scope (user or workspace).
    pub billing_scope: BillingScope,

    /// Effective plan tier (e.g., "free", "pro", "enterprise").
    pub plan_tier: String,

    /// Effective daily job quota (None = unlimited).
    pub daily_job_quota: Option<i64>,

    /// Billing currency (if applicable).
    pub billing_currency: Option<String>,

    /// Billing provider (e.g., "stripe", "alipay").
    pub billing_provider: Option<String>,

    /// User ID (always present).
    pub user_id: Uuid,

    /// Workspace ID (present when billing_scope = Workspace).
    pub workspace_id: Option<Uuid>,
}

/// Get the effective billing context for a user in a workspace.
///
/// This is the primary entry point for quota checks and billing display.
///
/// ## Resolution Logic
///
/// 1. Resolve billing scope using `resolve_billing_scope()`
/// 2. If `User` scope: Load billing data from `app_user_profile`
/// 3. If `Workspace` scope: Load billing data from `app_workspace`
///
/// ## Arguments
///
/// - `pool`: Database connection pool
/// - `user_id`: User requesting the operation
/// - `workspace_id`: Current workspace context
/// - `config`: Global billing configuration
///
/// ## Returns
///
/// - `Ok(EffectiveBillingContext)`: Resolved billing context
/// - `Err(ApiError)`: Database error or missing data
pub async fn get_effective_billing_context(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
    config: &BillingConfig,
) -> Result<EffectiveBillingContext, ApiError> {
    // 1. Resolve billing scope
    let billing_scope = resolve_billing_scope(pool, workspace_id, config).await?;

    match billing_scope {
        BillingScope::User => {
            // Load billing data from app_user_profile
            type UserBillingRow = (String, Option<i64>, Option<String>, Option<String>);
            let row: Option<UserBillingRow> = sqlx::query_as(
                r#"
                SELECT plan_tier, daily_job_quota, billing_currency, billing_provider
                FROM public.app_user_profile
                WHERE user_id = $1
                "#,
            )
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            let (plan_tier, daily_job_quota, billing_currency, billing_provider) =
                row.unwrap_or_else(|| ("free".to_string(), None, None, None));

            Ok(EffectiveBillingContext {
                billing_scope: BillingScope::User,
                plan_tier,
                daily_job_quota,
                billing_currency,
                billing_provider,
                user_id,
                workspace_id: None,
            })
        }
        BillingScope::Workspace => {
            // Load billing data from app_workspace
            type WorkspaceBillingRow =
                (Option<String>, Option<i64>, Option<String>, Option<String>);
            let row: Option<WorkspaceBillingRow> = sqlx::query_as(
                r#"
                SELECT plan_tier, daily_job_quota, billing_currency, billing_provider
                FROM public.app_workspace
                WHERE id = $1
                "#,
            )
            .bind(workspace_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            let (plan_tier_opt, daily_job_quota, billing_currency, billing_provider) =
                row.ok_or(ApiError::NotFound)?;

            // If workspace has no plan_tier, fall back to "free"
            // (This shouldn't happen if resolve_billing_scope is correct, but defensive)
            let plan_tier = plan_tier_opt.unwrap_or_else(|| "free".to_string());

            Ok(EffectiveBillingContext {
                billing_scope: BillingScope::Workspace,
                plan_tier,
                daily_job_quota,
                billing_currency,
                billing_provider,
                user_id,
                workspace_id: Some(workspace_id),
            })
        }
    }
}

#[cfg(test)]
#[path = "billing_context_test.rs"]
mod billing_context_test;
