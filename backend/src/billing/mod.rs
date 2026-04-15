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

mod events_list;
mod ingest;
mod openapi;
mod provider_adapter;
mod provider_rules;
mod verify;

pub use openapi::BillingApi;

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

use events_list::list_billing_webhook_events;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/webhooks/billing", post(post_billing_webhook))
        .route(
            "/api/v1/webhooks/billing/events",
            get(list_billing_webhook_events),
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

    let v: Value = serde_json::from_slice(&body)
        .map_err(|_| ApiError::BadRequest("body must be valid JSON".into()))?;

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
