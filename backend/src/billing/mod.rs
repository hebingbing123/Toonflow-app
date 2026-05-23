//! 计费模块：提供商 Webhook 处理（§12 / §13）。
//!
//! HMAC 验证的摄取 + 按提供商事件 ID 的幂等去重。
//! 首次接收时，可选的 `user_id` + `plan_tier` 会更新 `app_user_profile`。
//!
//! 子模块：
//! - `ingest` — Webhook 摄取和处理
//! - `verify` — HMAC 签名验证
//! - `provider_adapter` — 提供商适配器
//! - `provider_rules` — 提供商规则
//! - `events_list` — `GET /api/v1/webhooks/billing/events` 审计查询
//! - `reconciliation_worker` — 定期对账任务（Task 4.3）
//! - `ops_view` — Internal ops endpoints for workspace billing queries (Task 8.1)

mod checkout;
mod estimate_enrich;
mod events_list;
mod ingest;
mod openapi;
mod ops_view;
mod provider_adapter;
mod provider_rules;
mod reconciliation_worker;
mod user_pricing;
mod verify;

pub use openapi::BillingApi;
// Re-export reconciliation functions for ops/monitoring (Task 4.3)
pub use ingest::{
    check_personal_workspace_billing_consistency, reconcile_all_personal_workspaces,
    BillingMismatch,
};
// Re-export ingest_webhook for integration tests (Task 4.2)
pub use ingest::ingest_webhook;
// Re-export reconciliation worker (Task 4.3)
pub use reconciliation_worker::run as run_reconciliation_worker;

use axum::body::Bytes;
use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Serialize;
use serde_json::Value;
use utoipa::ToSchema;

use crate::error::ApiError;
use crate::state::AppState;

use checkout::{
    get_billing_plans, get_checkout_session, get_mock_pay, post_alipay_notify,
    post_billing_checkout, post_billing_portal, post_bitpay_notify, post_stripe_checkout_webhook,
};
use events_list::list_billing_webhook_events;
use ops_view::{get_workspace_job_aggregates, get_workspace_subscription};
use user_pricing::{get_billing_spend_summary, post_billing_estimate};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/billing/plans", get(get_billing_plans))
        .route("/api/v1/billing/checkout", post(post_billing_checkout))
        .route(
            "/api/v1/billing/checkout/:session_id",
            get(get_checkout_session),
        )
        .route(
            "/api/v1/billing/checkout/:session_id/mock-pay",
            get(get_mock_pay),
        )
        .route("/api/v1/billing/portal", post(post_billing_portal))
        .route("/api/v1/webhooks/billing/alipay", post(post_alipay_notify))
        .route(
            "/api/v1/webhooks/billing/stripe",
            post(post_stripe_checkout_webhook),
        )
        .route("/api/v1/webhooks/billing/bitpay", post(post_bitpay_notify))
        .route("/api/v1/webhooks/billing", post(post_billing_webhook))
        .route(
            "/api/v1/webhooks/billing/events",
            get(list_billing_webhook_events),
        )
        .route(
            "/api/v1/webhooks/billing/reconcile",
            post(post_billing_reconcile),
        )
        // Internal ops endpoints (Task 8.1)
        .route(
            "/api/v1/ops/billing/workspace-subscription",
            get(get_workspace_subscription),
        )
        .route(
            "/api/v1/ops/billing/workspace-job-aggregates",
            get(get_workspace_job_aggregates),
        )
        .route("/api/v1/billing/estimate", post(post_billing_estimate))
        .route(
            "/api/v1/billing/spend-summary",
            get(get_billing_spend_summary),
        )
}

// ── POST /api/v1/webhooks/billing ─────────────────────────────────────────────

#[derive(Debug, Serialize, ToSchema)]
struct BillingWebhookResponse {
    received: bool,
    duplicate: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[schema(nullable = true)]
    provider_event_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    profile_updated: Option<bool>,
    informational_event: bool,
}

#[utoipa::path(
    post,
    path = "/api/v1/webhooks/billing",
    operation_id = "postBillingWebhookV1",
    tag = "webhooks",
    request_body(content = serde_json::Value, content_type = "application/json", description = "Provider-specific billing JSON payload"),
    params(
        ("Accept-Language" = Option<String>, Header, description = "Preferred language for localized error `message` fields. Supports `en` and `zh`; defaults to `en`. Machine-readable `code` fields remain stable.")
    ),
    responses(
        (status = 200, description = "Accepted (or duplicate replay)", body = BillingWebhookResponse),
        (status = 400, description = "Invalid JSON", body = crate::error::ErrorBody),
        (status = 401, description = "Missing/bad signature", body = crate::error::ErrorBody),
        (status = 503, description = "Secret or database not configured", body = crate::error::ErrorBody)
    )
)]
async fn post_billing_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> Result<Json<BillingWebhookResponse>, ApiError> {
    let secret = verify::billing_secret()?;
    verify::verify_signature(&secret, &body, &headers)?;

    let pool = state.require_pool()?;

    let v: Value = serde_json::from_slice(&body).map_err(|_| {
        crate::error::bad_request_i18n("body must be valid JSON", "body 必须是有效的 JSON")
    })?;

    let (duplicate, row_id, profile_updated, provider_event_id, informational_event) =
        ingest::ingest_webhook(pool, &v).await?;

    Ok(Json(BillingWebhookResponse {
        received: true,
        duplicate,
        id: row_id,
        provider_event_id: Some(provider_event_id).filter(|s| !s.is_empty()),
        profile_updated: if duplicate {
            None
        } else {
            Some(profile_updated)
        },
        informational_event,
    }))
}

// ── POST /api/v1/webhooks/billing/reconcile ──────────────────────────────────

#[derive(Debug, Serialize, ToSchema)]
struct BillingReconcileResponse {
    total_users_checked: usize,
    mismatch_count: usize,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    mismatches: Vec<BillingMismatchDetail>,
}

#[derive(Debug, Serialize, ToSchema)]
struct BillingMismatchDetail {
    user_id: String,
    workspace_id: String,
    field: String,
    user_value: Option<String>,
    workspace_value: Option<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/webhooks/billing/reconcile",
    operation_id = "postBillingReconcileV1",
    tag = "webhooks",
    responses(
        (status = 200, description = "Reconciliation completed", body = BillingReconcileResponse),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(
        ("bearer" = [])
    )
)]
async fn post_billing_reconcile(
    State(state): State<AppState>,
) -> Result<Json<BillingReconcileResponse>, ApiError> {
    let pool = state.require_pool()?;

    // Get all users with personal workspaces
    let user_ids: Vec<(uuid::Uuid,)> = sqlx::query_as(
        r#"
        SELECT DISTINCT u.user_id
        FROM app_user_profile u
        INNER JOIN app_workspace w ON w.owner_user_id = u.user_id
        WHERE w.workspace_type = 'personal'
        "#,
    )
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_users_checked = user_ids.len();
    let mut all_mismatches = Vec::new();

    for (user_id,) in user_ids {
        let mismatches = check_personal_workspace_billing_consistency(pool, user_id)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        all_mismatches.extend(mismatches);
    }

    let mismatch_count = all_mismatches.len();

    let mismatches: Vec<BillingMismatchDetail> = all_mismatches
        .into_iter()
        .map(|m| BillingMismatchDetail {
            user_id: m.user_id.to_string(),
            workspace_id: m.workspace_id.to_string(),
            field: m.field,
            user_value: m.user_value,
            workspace_value: m.workspace_value,
        })
        .collect();

    Ok(Json(BillingReconcileResponse {
        total_users_checked,
        mismatch_count,
        mismatches,
    }))
}
