//! `GET /api/v1/usage/summary`：用量与配额提示。

use std::collections::HashMap;

use axum::extract::{Query, State};
use axum::http::HeaderMap;
use axum::Json;
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::quota;
use crate::state::AppState;

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub(crate) enum UsageSummaryScope {
    User,
    Workspace,
}

#[derive(Deserialize, IntoParams)]
pub(crate) struct UsageSummaryQuery {
    /// Aggregation scope for usage metrics.
    /// - `user`: Aggregate for current user only (default, backward compatible)
    /// - `workspace`: Aggregate for current workspace (requires workspace context)
    #[serde(default)]
    pub(crate) scope: Option<String>,
}

#[derive(Serialize, ToSchema)]
pub(crate) struct UsageSummaryResponse {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub(crate) scope: UsageSummaryScope,
    pub(crate) events_last_24h: i64,
    pub(crate) events_last_7d: i64,
    /// Per-`event_type` counts in the rolling last 7 days (same window as `events_last_7d`).
    pub(crate) event_counts_last_7d: HashMap<String, i64>,
    /// Jobs created today (UTC natural day) — same counter used by quota enforcement.
    pub(crate) jobs_today: i64,
    /// Effective daily job cap (`null` = unlimited).
    pub(crate) daily_job_quota: Option<i64>,
    /// Remaining jobs allowed today (`null` = unlimited). `0` means quota is exhausted.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) quota_remaining: Option<i64>,
    /// Workspace ID (present when scope=workspace).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) workspace_id: Option<Uuid>,
    /// Workspace name (present when scope=workspace, for UI display).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) workspace_name: Option<String>,
}

#[utoipa::path(
    get,
    path = "/api/v1/usage/summary",
    operation_id = "usageSummaryV1",
    tag = "usage",
    params(UsageSummaryQuery),
    responses(
        (status = 200, description = "OK", body = UsageSummaryResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(super) async fn usage_summary(
    State(state): State<AppState>,
    Query(query): Query<UsageSummaryQuery>,
    headers: HeaderMap,
) -> Result<Json<UsageSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // Parse scope parameter (default to "user" for backward compatibility)
    let requested_scope = query.scope.as_deref().unwrap_or("user");

    match requested_scope {
        "user" => usage_summary_user_scope(pool, uid).await,
        "workspace" => usage_summary_workspace_scope(pool, uid).await,
        _ => Err(ApiError::BadRequest(format!(
            "Invalid scope '{}'. Valid values: 'user', 'workspace'",
            requested_scope
        ))),
    }
}

/// User-scope usage summary (legacy behavior, default).
async fn usage_summary_user_scope(
    pool: &sqlx::PgPool,
    uid: Uuid,
) -> Result<Json<UsageSummaryResponse>, ApiError> {
    // Event counts (24h / 7d).
    let row: (i64, i64) = sqlx::query_as(
        r#"
        SELECT
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '1 day'
            )::bigint,
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '7 days'
            )::bigint
        FROM app_usage_event
        WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let breakdown: Vec<(String, i64)> = sqlx::query_as(
        r#"
        SELECT event_type, COUNT(*)::bigint
        FROM app_usage_event
        WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '7 days'
        GROUP BY event_type
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let event_counts_last_7d: HashMap<String, i64> = breakdown.into_iter().collect();

    // Jobs created today (UTC midnight to now) — used for quota display.
    let jobs_today: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Effective quota for this user.
    let daily_job_quota = quota::effective_daily_job_quota_for_user(pool, uid)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let quota_remaining = daily_job_quota.map(|cap| (cap - jobs_today).max(0));

    Ok(Json(UsageSummaryResponse {
        scope: UsageSummaryScope::User,
        events_last_24h: row.0,
        events_last_7d: row.1,
        event_counts_last_7d,
        jobs_today,
        daily_job_quota,
        quota_remaining,
        workspace_id: None,
        workspace_name: None,
    }))
}

/// Workspace-scope usage summary (aggregates across workspace members).
async fn usage_summary_workspace_scope(
    pool: &sqlx::PgPool,
    uid: Uuid,
) -> Result<Json<UsageSummaryResponse>, ApiError> {
    use crate::metering::{get_effective_billing_context, BillingConfig, BillingScope};

    // Get user's current workspace from session/profile
    let current_workspace_id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT current_workspace_id
        FROM public.app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .flatten();

    let workspace_id = current_workspace_id.ok_or_else(|| {
        ApiError::BadRequest(
            "Workspace scope requires a current workspace context. Set current_workspace_id."
                .to_string(),
        )
    })?;

    // Verify user has access to this workspace (member check)
    let is_member: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM public.app_workspace_member
            WHERE workspace_id = $1 AND user_id = $2
        )
        "#,
    )
    .bind(workspace_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !is_member {
        return Err(ApiError::Forbidden(
            "You do not have access to this workspace".to_string(),
        ));
    }

    // Get workspace name for display
    let workspace_name: Option<String> = sqlx::query_scalar(
        r#"
        SELECT name
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Get all workspace member IDs for event aggregation
    let member_ids: Vec<Uuid> = sqlx::query_scalar(
        r#"
        SELECT user_id
        FROM public.app_workspace_member
        WHERE workspace_id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Event counts (24h / 7d) aggregated across workspace members
    let row: (i64, i64) = sqlx::query_as(
        r#"
        SELECT
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '1 day'
            )::bigint,
            COUNT(*) FILTER (
                WHERE created_at >= NOW() - INTERVAL '7 days'
            )::bigint
        FROM app_usage_event
        WHERE user_id = ANY($1)
        "#,
    )
    .bind(&member_ids)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let breakdown: Vec<(String, i64)> = sqlx::query_as(
        r#"
        SELECT event_type, COUNT(*)::bigint
        FROM app_usage_event
        WHERE user_id = ANY($1) AND created_at >= NOW() - INTERVAL '7 days'
        GROUP BY event_type
        "#,
    )
    .bind(&member_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let event_counts_last_7d: HashMap<String, i64> = breakdown.into_iter().collect();

    // Jobs created today (UTC midnight to now) — workspace-scoped via workspace_id
    let jobs_today: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE workspace_id = $1
          AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
        "#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Get effective billing context for workspace
    let billing_config = BillingConfig::from_env();
    let context = get_effective_billing_context(pool, uid, workspace_id, &billing_config).await?;

    // Verify billing scope is actually workspace (defensive check)
    if context.billing_scope != BillingScope::Workspace {
        return Err(ApiError::BadRequest(
            "Workspace scope requested but workspace billing is not enabled for this workspace"
                .to_string(),
        ));
    }

    let daily_job_quota = context.daily_job_quota;
    let quota_remaining = daily_job_quota.map(|cap| (cap - jobs_today).max(0));

    Ok(Json(UsageSummaryResponse {
        scope: UsageSummaryScope::Workspace,
        events_last_24h: row.0,
        events_last_7d: row.1,
        event_counts_last_7d,
        jobs_today,
        daily_job_quota,
        quota_remaining,
        workspace_id: Some(workspace_id),
        workspace_name,
    }))
}
