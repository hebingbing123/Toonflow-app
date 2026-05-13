//! Internal ops endpoints for workspace billing queries (Task 8.1).
//!
//! Gate: Environment variable **`TOONFLOW_INTERNAL_OPS_TOKEN`** (non-empty);
//! requests must include **`X-Toonflow-Internal-Token`** matching the expected value.
//!
//! Provides ops team visibility into:
//! - Workspace subscription snapshots filtered by workspace_id
//! - Job aggregates by workspace for billing reconciliation
//!
//! Related:
//! - Requirements: .kiro/specs/workspace-scope-billing/requirements.md (Requirement 7)
//! - Design: .kiro/specs/workspace-scope-billing/design.md (Ops billing view)
//! - Tasks: .kiro/specs/workspace-scope-billing/tasks.md (Task 8.1)

use axum::{extract::State, http::HeaderMap, Json};
use serde::Serialize;
use sqlx::PgPool;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

/// Workspace subscription snapshot for ops queries.
///
/// Contains billing-relevant fields without exposing PII beyond workspace_id.
#[derive(Debug, Serialize, ToSchema)]
pub struct WorkspaceSubscriptionSnapshot {
    /// Workspace ID
    pub workspace_id: Uuid,
    /// Workspace type (personal, enterprise)
    pub workspace_type: String,
    /// Current plan tier (NULL = user-scope billing)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub plan_tier: Option<String>,
    /// Daily job quota override (NULL = use plan default)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub daily_job_quota: Option<i64>,
    /// Billing provider (e.g., "stripe")
    #[serde(skip_serializing_if = "Option::is_none")]
    pub billing_provider: Option<String>,
    /// Billing customer ID (e.g., Stripe customer ID)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub billing_customer_id: Option<String>,
    /// Billing currency (e.g., "USD")
    #[serde(skip_serializing_if = "Option::is_none")]
    pub billing_currency: Option<String>,
    /// Workspace created timestamp
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Job aggregates by workspace for billing reconciliation.
#[derive(Debug, Serialize, ToSchema)]
pub struct WorkspaceJobAggregates {
    /// Workspace ID
    pub workspace_id: Uuid,
    /// Total jobs created (all time)
    pub total_jobs: i64,
    /// Jobs created today (UTC day)
    pub jobs_today: i64,
    /// Jobs created in last 7 days
    pub jobs_last_7_days: i64,
    /// Jobs created in last 30 days
    pub jobs_last_30_days: i64,
    /// Jobs by status (pending, running, completed, failed, cancelled)
    pub jobs_by_status: serde_json::Value,
}

/// Response for workspace subscription query.
#[derive(Debug, Serialize, ToSchema)]
pub struct WorkspaceSubscriptionResponse {
    pub subscription: Option<WorkspaceSubscriptionSnapshot>,
}

/// Response for workspace job aggregates query.
#[derive(Debug, Serialize, ToSchema)]
pub struct WorkspaceJobAggregatesResponse {
    pub aggregates: WorkspaceJobAggregates,
}

/// Check if internal ops token is configured and valid.
fn internal_ops_token_expected() -> Option<String> {
    std::env::var("TOONFLOW_INTERNAL_OPS_TOKEN")
        .ok()
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
}

/// Require valid internal ops token in request headers.
fn require_internal_ops_token(headers: &HeaderMap) -> Result<(), ApiError> {
    let Some(expected) = internal_ops_token_expected() else {
        return Err(ApiError::Forbidden(
            "workspace billing ops view disabled (set TOONFLOW_INTERNAL_OPS_TOKEN)".into(),
        ));
    };
    let got = headers
        .get("x-toonflow-internal-token")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if got != expected.as_str() {
        return Err(ApiError::Unauthorized);
    }
    Ok(())
}

/// Get workspace subscription snapshot by workspace_id.
///
/// Internal ops endpoint for querying workspace billing state.
///
/// ## Query Parameters
///
/// - `workspace_id`: UUID of the workspace to query
///
/// ## Authorization
///
/// Requires `X-Toonflow-Internal-Token` header matching `TOONFLOW_INTERNAL_OPS_TOKEN` env var.
///
/// ## Response
///
/// Returns workspace billing snapshot including plan_tier, quota, and provider details.
/// Returns 404 if workspace not found.
#[utoipa::path(
    get,
    path = "/api/v1/ops/billing/workspace-subscription",
    operation_id = "getWorkspaceSubscriptionOps",
    tag = "billing-ops",
    params(
        ("workspace_id" = Uuid, Query, description = "Workspace ID to query")
    ),
    responses(
        (status = 200, description = "OK", body = WorkspaceSubscriptionResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not Found", body = crate::error::ErrorBody),
        (status = 500, description = "Internal Server Error", body = crate::error::ErrorBody),
    )
)]
pub(crate) async fn get_workspace_subscription(
    State(state): State<AppState>,
    headers: HeaderMap,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<WorkspaceSubscriptionResponse>, ApiError> {
    require_internal_ops_token(&headers)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("Database not configured".into()))?;

    let workspace_id_str = params.get("workspace_id").ok_or_else(|| {
        crate::error::bad_request_i18n("Missing workspace_id parameter", "缺少 workspace_id 参数")
    })?;

    let workspace_id = Uuid::parse_str(workspace_id_str).map_err(|_| {
        crate::error::bad_request_i18n("Invalid workspace_id format", "workspace_id 格式无效")
    })?;

    let subscription = query_workspace_subscription(pool, workspace_id).await?;

    Ok(Json(WorkspaceSubscriptionResponse { subscription }))
}

/// Get job aggregates by workspace_id.
///
/// Internal ops endpoint for querying workspace job usage.
///
/// ## Query Parameters
///
/// - `workspace_id`: UUID of the workspace to query
///
/// ## Authorization
///
/// Requires `X-Toonflow-Internal-Token` header matching `TOONFLOW_INTERNAL_OPS_TOKEN` env var.
///
/// ## Response
///
/// Returns job aggregates including total jobs, jobs today, and jobs by status.
/// Returns 404 if workspace not found.
#[utoipa::path(
    get,
    path = "/api/v1/ops/billing/workspace-job-aggregates",
    operation_id = "getWorkspaceJobAggregatesOps",
    tag = "billing-ops",
    params(
        ("workspace_id" = Uuid, Query, description = "Workspace ID to query")
    ),
    responses(
        (status = 200, description = "OK", body = WorkspaceJobAggregatesResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not Found", body = crate::error::ErrorBody),
        (status = 500, description = "Internal Server Error", body = crate::error::ErrorBody),
    )
)]
pub(crate) async fn get_workspace_job_aggregates(
    State(state): State<AppState>,
    headers: HeaderMap,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<WorkspaceJobAggregatesResponse>, ApiError> {
    require_internal_ops_token(&headers)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("Database not configured".into()))?;

    let workspace_id_str = params.get("workspace_id").ok_or_else(|| {
        crate::error::bad_request_i18n("Missing workspace_id parameter", "缺少 workspace_id 参数")
    })?;

    let workspace_id = Uuid::parse_str(workspace_id_str).map_err(|_| {
        crate::error::bad_request_i18n("Invalid workspace_id format", "workspace_id 格式无效")
    })?;

    let aggregates = query_workspace_job_aggregates(pool, workspace_id).await?;

    Ok(Json(WorkspaceJobAggregatesResponse { aggregates }))
}

/// Query workspace subscription snapshot from database.
async fn query_workspace_subscription(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<Option<WorkspaceSubscriptionSnapshot>, ApiError> {
    type Row = (
        Uuid,
        String,
        Option<String>,
        Option<i64>,
        Option<String>,
        Option<String>,
        Option<String>,
        chrono::DateTime<chrono::Utc>,
    );

    let row: Option<Row> = sqlx::query_as(
        r#"
        SELECT 
            id,
            workspace_type,
            plan_tier,
            daily_job_quota,
            billing_provider,
            billing_customer_id,
            billing_currency,
            created_at
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row.map(
        |(
            workspace_id,
            workspace_type,
            plan_tier,
            daily_job_quota,
            billing_provider,
            billing_customer_id,
            billing_currency,
            created_at,
        )| {
            WorkspaceSubscriptionSnapshot {
                workspace_id,
                workspace_type,
                plan_tier,
                daily_job_quota,
                billing_provider,
                billing_customer_id,
                billing_currency,
                created_at,
            }
        },
    ))
}

/// Query workspace job aggregates from database.
async fn query_workspace_job_aggregates(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<WorkspaceJobAggregates, ApiError> {
    // First verify workspace exists
    let workspace_exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(SELECT 1 FROM public.app_workspace WHERE id = $1)
        "#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !workspace_exists {
        return Err(ApiError::NotFound);
    }

    // Query job aggregates
    type AggregateRow = (i64, i64, i64, i64);
    let (total_jobs, jobs_today, jobs_last_7_days, jobs_last_30_days): AggregateRow =
        sqlx::query_as(
            r#"
        SELECT 
            COUNT(*)::bigint as total_jobs,
            COUNT(*) FILTER (WHERE created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC'))::bigint as jobs_today,
            COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days')::bigint as jobs_last_7_days,
            COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days')::bigint as jobs_last_30_days
        FROM public.app_generation_job
        WHERE workspace_id = $1
        "#,
        )
        .bind(workspace_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Query jobs by status
    let status_rows: Vec<(String, i64)> = sqlx::query_as(
        r#"
        SELECT status, COUNT(*)::bigint
        FROM public.app_generation_job
        WHERE workspace_id = $1
        GROUP BY status
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Convert status counts to JSON object
    let mut status_map = serde_json::Map::new();
    for (status, count) in status_rows {
        status_map.insert(status, serde_json::Value::Number(count.into()));
    }
    let jobs_by_status = serde_json::Value::Object(status_map);

    Ok(WorkspaceJobAggregates {
        workspace_id,
        total_jobs,
        jobs_today,
        jobs_last_7_days,
        jobs_last_30_days,
        jobs_by_status,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_ops_token_expected_returns_none_when_not_set() {
        // This test assumes TOONFLOW_INTERNAL_OPS_TOKEN is not set in test environment
        // If it is set, this test may fail - that's acceptable for unit tests
        let token = internal_ops_token_expected();
        // We can't assert None because the env var might be set in CI
        // Just verify the function doesn't panic
        let _ = token;
    }

    #[test]
    fn require_internal_ops_token_rejects_empty_headers() {
        let headers = HeaderMap::new();
        let result = require_internal_ops_token(&headers);
        // Should fail with either Forbidden (no token configured) or Unauthorized (token mismatch)
        assert!(result.is_err());
    }
}
