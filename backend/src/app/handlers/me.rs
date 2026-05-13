//! `GET /api/v1/me` — JWT sub + `app_user_profile` 等。
//!
//! **Task 5**: Versioned `/me` response (v1 default, v2 opt-in via `?v=2`).

use axum::extract::{Query, State};
use axum::http::HeaderMap;
use axum::Json;
use chrono::{DateTime, Utc};
use serde::Deserialize;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::{bearer_token, require_claims, require_user_uuid};
use crate::error::ApiError;
use crate::metering::{get_effective_billing_context, BillingScope};
use crate::state::{AppState, MemoryConfig};

use crate::workspaces::ensure_personal_workspace;

use super::types::{
    MeResponse, MeV2Response, UserBillingSummary, WorkspaceBillingSummary, WorkspaceSummary,
};

#[derive(Debug, Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub struct PatchCurrentWorkspaceBody {
    pub workspace_id: Uuid,
}

#[derive(Debug, Deserialize)]
pub struct MeQueryParams {
    /// API version: "2" for v2 response, omit or "1" for v1 (default).
    pub v: Option<String>,
}

fn request_id_from_headers(headers: &HeaderMap) -> Option<&str> {
    headers
        .get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|v| !v.is_empty())
}

#[derive(FromRow)]
struct UserProfileRow {
    plan_tier: String,
    billing_currency: Option<String>,
    billing_provider: Option<String>,
    subscription_status: Option<String>,
    subscription_current_period_end_at: Option<DateTime<Utc>>,
    daily_job_quota: Option<i64>,
    memory_config: Option<sqlx::types::Json<MemoryConfig>>,
    current_workspace_id: Option<Uuid>,
}

#[utoipa::path(
    get,
    path = "/api/v1/me",
    operation_id = "meV1",
    tag = "session",
    summary = "Current user from JWT plus SaaS profile when database is configured",
    description = "Always returns JWT `sub` (and `email` when present in claims). When **`DATABASE_URL`** is set, loads **`plan_tier`** / billing fields from **`app_user_profile`** (defaults to **`plan_tier: free`** when no row).\nIncludes `subscription_status` and `subscription_current_period_end_at` when present in profile.\nAlso returns **`daily_job_quota`** (effective cap; `null` = unlimited) and **`jobs_today`** (UTC-day count) when the database is connected — clients can use these to render quota progress without a separate call.\n\n**Versioning (Task 5.2)**: Add `?v=2` query parameter for v2 response with nested `user` + `current_workspace_billing` fields.",
    params(
        ("v" = Option<String>, Query, description = "API version: '2' for v2 response, omit or '1' for v1 (default)")
    ),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "OK (v1 response)", body = MeResponse),
        (status = 200, description = "OK (v2 response when ?v=2)", body = MeV2Response),
        (status = 401, description = "Missing or invalid Bearer token", body = crate::error::ErrorBody),
        (status = 503, description = "`SUPABASE_JWT_SECRET` not configured, or database error when loading profile", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn me(
    State(state): State<AppState>,
    Query(params): Query<MeQueryParams>,
    headers: HeaderMap,
) -> Result<Json<serde_json::Value>, ApiError> {
    let sub = require_user_uuid(&state, &headers)?;
    let claims = if bearer_token(&headers).is_some_and(|token| token.contains('.')) {
        Some(require_claims(&state, &headers)?)
    } else {
        None
    };
    let request_id = request_id_from_headers(&headers);

    // Check if v2 is requested
    let is_v2 = params.v.as_deref() == Some("2");

    let (
        plan_tier,
        billing_currency,
        billing_provider,
        subscription_status,
        subscription_current_period_end_at,
        per_user_quota,
        jobs_today,
        memory_cfg,
        current_workspace,
    ) = if let Some(pool) = state.pool.as_ref() {
        let personal_workspace = ensure_personal_workspace(pool, sub).await?;
        let row = sqlx::query_as::<_, UserProfileRow>(
            r#"
            SELECT
              plan_tier,
              billing_currency,
              billing_provider,
              subscription_status,
              subscription_current_period_end_at,
              daily_job_quota,
              memory_config,
              current_workspace_id
            FROM app_user_profile
            WHERE user_id = $1
            "#,
        )
        .bind(sub)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let (
            tier,
            currency,
            provider,
            subscription_status,
            subscription_current_period_end_at,
            per_user_quota,
            mem_cfg,
            current_workspace_id,
        ) = match row {
            Some(r) => (
                r.plan_tier,
                r.billing_currency,
                r.billing_provider,
                r.subscription_status,
                r.subscription_current_period_end_at,
                r.daily_job_quota,
                r.memory_config.map(|j| j.0),
                r.current_workspace_id,
            ),
            None => ("free".to_string(), None, None, None, None, None, None, None),
        };

        let today: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE owner_user_id = $1
              AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
            "#,
        )
        .bind(sub)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let current_workspace = if let Some(current_id) = current_workspace_id {
            let row: Option<(Uuid, String, String)> = sqlx::query_as(
                r#"
                SELECT w.id, w.name, w.workspace_type::text
                FROM public.app_workspace w
                INNER JOIN public.app_workspace_member m ON m.workspace_id = w.id
                WHERE w.id = $1
                  AND m.user_id = $2
                LIMIT 1
                "#,
            )
            .bind(current_id)
            .bind(sub)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            if let Some((id, name, workspace_type)) = row {
                WorkspaceSummary {
                    id,
                    name,
                    workspace_type,
                }
            } else {
                // Profile points to a stale/non-member workspace; heal to personal.
                sqlx::query(
                    r#"
                    UPDATE public.app_user_profile
                    SET current_workspace_id = $2, updated_at = NOW()
                    WHERE user_id = $1
                    "#,
                )
                .bind(sub)
                .bind(personal_workspace.workspace_id)
                .execute(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

                tracing::info!(
                    event = "current_workspace_fallback",
                    request_id = request_id.unwrap_or(""),
                    user_id = %sub,
                    stale_workspace_id = %current_id,
                    workspace_id = %personal_workspace.workspace_id,
                    outcome = "fallback_personal",
                    "current workspace healed to personal"
                );

                WorkspaceSummary {
                    id: personal_workspace.workspace_id,
                    name: personal_workspace.workspace_name.clone(),
                    workspace_type: personal_workspace.workspace_type.clone(),
                }
            }
        } else {
            WorkspaceSummary {
                id: personal_workspace.workspace_id,
                name: personal_workspace.workspace_name.clone(),
                workspace_type: personal_workspace.workspace_type.clone(),
            }
        };

        (
            tier,
            currency,
            provider,
            subscription_status,
            subscription_current_period_end_at,
            per_user_quota,
            Some(today),
            mem_cfg,
            Some(current_workspace),
        )
    } else {
        (
            "free".to_string(),
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            None,
        )
    };

    // Resolve effective quota using same logic as quota::effective_daily_job_quota
    // but inline (avoids a second DB round-trip).
    let daily_job_quota = if per_user_quota.is_some() {
        per_user_quota
    } else {
        let free_limit = std::env::var("QUOTA_FREE_DAILY_JOBS")
            .ok()
            .and_then(|s| s.trim().parse::<i64>().ok())
            .filter(|&n| n > 0)
            .unwrap_or(20);
        match plan_tier.as_str() {
            "enterprise" => None,
            "free" => Some(free_limit),
            "creator" => Some(free_limit * 40),
            "pro" => Some(free_limit * 125),
            "studio" => Some(free_limit * 400),
            _ => Some(free_limit),
        }
    };

    // Resolve memory_config (use DB value or fall back to server defaults).
    let memory_config = if memory_cfg.is_some() {
        memory_cfg
    } else if state.pool.is_none() {
        Some(state.memory_config.read().await.clone())
    } else {
        None // DB connected but user has no custom config; don't leak server defaults.
    };

    // Return v2 response if requested (Task 5.3)
    if is_v2 {
        return me_v2_response(
            &state,
            sub,
            claims.and_then(|c| c.email),
            plan_tier,
            billing_currency,
            billing_provider,
            subscription_status,
            subscription_current_period_end_at,
            daily_job_quota,
            jobs_today,
            memory_config,
            current_workspace,
        )
        .await;
    }

    // V1 response (default)
    Ok(Json(
        serde_json::to_value(MeResponse {
            sub,
            email: claims.and_then(|c| c.email),
            plan_tier,
            billing_currency,
            billing_provider,
            subscription_status,
            subscription_current_period_end_at,
            daily_job_quota,
            jobs_today,
            memory_config,
            current_workspace,
        })
        .unwrap(),
    ))
}

/// Build v2 response with nested billing context (Task 5.3).
#[allow(clippy::too_many_arguments)]
async fn me_v2_response(
    state: &AppState,
    sub: Uuid,
    email: Option<String>,
    plan_tier: String,
    billing_currency: Option<String>,
    billing_provider: Option<String>,
    subscription_status: Option<String>,
    subscription_current_period_end_at: Option<DateTime<Utc>>,
    daily_job_quota: Option<i64>,
    jobs_today: Option<i64>,
    memory_config: Option<MemoryConfig>,
    current_workspace: Option<WorkspaceSummary>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let pool = state.require_pool()?;

    // Get current workspace ID
    let current_workspace_id = current_workspace.as_ref().map(|w| w.id);

    // Resolve effective billing context
    let billing_context = if let Some(workspace_id) = current_workspace_id {
        get_effective_billing_context(pool, sub, workspace_id, &state.billing_config).await?
    } else {
        // No current workspace; fall back to user-scope
        return Ok(Json(
            serde_json::to_value(MeV2Response {
                billing_scope: "user".to_string(),
                user: UserBillingSummary {
                    sub,
                    email,
                    plan_tier,
                    billing_currency,
                    billing_provider,
                    subscription_status,
                    subscription_current_period_end_at,
                    daily_job_quota,
                    jobs_today,
                },
                current_workspace_billing: None,
                memory_config,
                current_workspace,
            })
            .unwrap(),
        ));
    };

    let billing_scope_str = match billing_context.billing_scope {
        BillingScope::User => "user",
        BillingScope::Workspace => "workspace",
    };

    // Build workspace billing summary if workspace-scope
    let current_workspace_billing = if billing_context.billing_scope == BillingScope::Workspace {
        let workspace_id = current_workspace_id.unwrap(); // Safe: we checked above

        // Get workspace jobs_today
        let workspace_jobs_today: i64 = sqlx::query_scalar(
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

        Some(WorkspaceBillingSummary {
            workspace_id,
            workspace_type: current_workspace.as_ref().unwrap().workspace_type.clone(),
            plan_tier: billing_context.plan_tier.clone(),
            billing_currency: billing_context.billing_currency.clone(),
            billing_provider: billing_context.billing_provider.clone(),
            daily_job_quota: billing_context.daily_job_quota,
            jobs_today: Some(workspace_jobs_today),
        })
    } else {
        None
    };

    Ok(Json(
        serde_json::to_value(MeV2Response {
            billing_scope: billing_scope_str.to_string(),
            user: UserBillingSummary {
                sub,
                email,
                plan_tier,
                billing_currency,
                billing_provider,
                subscription_status,
                subscription_current_period_end_at,
                daily_job_quota,
                jobs_today,
            },
            current_workspace_billing,
            memory_config,
            current_workspace,
        })
        .unwrap(),
    ))
}

#[utoipa::path(
    patch,
    path = "/api/v1/me/current-workspace",
    operation_id = "patchCurrentWorkspaceV1",
    tag = "session",
    request_body(content = PatchCurrentWorkspaceBody, content_type = "application/json"),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "OK", body = WorkspaceSummary),
        (status = 401, description = "Missing or invalid Bearer token", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn patch_current_workspace(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PatchCurrentWorkspaceBody>,
) -> Result<Json<WorkspaceSummary>, ApiError> {
    let sub = require_user_uuid(&state, &headers)?;
    let request_id = request_id_from_headers(&headers);
    let pool = state.require_pool()?;
    let workspace_id = body.workspace_id;

    let exists: bool =
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM public.app_workspace WHERE id = $1)")
            .bind(workspace_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !exists {
        return Err(ApiError::NotFound);
    }

    let is_member: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM public.app_workspace_member WHERE workspace_id = $1 AND user_id = $2)",
    )
    .bind(workspace_id)
    .bind(sub)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !is_member {
        return Err(ApiError::Forbidden(
            "not a member of the target workspace".into(),
        ));
    }

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, current_workspace_id)
        VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE
        SET current_workspace_id = EXCLUDED.current_workspace_id, updated_at = NOW()
        "#,
    )
    .bind(sub)
    .bind(workspace_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row: Option<(Uuid, String, String)> = sqlx::query_as(
        r#"
        SELECT id, name, workspace_type::text
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some((id, name, workspace_type)) = row else {
        return Err(ApiError::NotFound);
    };

    tracing::info!(
        event = "current_workspace_switch",
        request_id = request_id.unwrap_or(""),
        user_id = %sub,
        workspace_id = %workspace_id,
        outcome = "switched",
        "current workspace switched"
    );

    Ok(Json(WorkspaceSummary {
        id,
        name,
        workspace_type,
    }))
}
