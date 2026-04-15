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

mod ingest;
mod openapi;
mod provider_adapter;
mod provider_rules;
mod verify;

pub use openapi::BillingApi;

use axum::body::Bytes;
use axum::extract::{Query, State};
use axum::http::HeaderMap;
use axum::routing::{get, post};
use axum::{Json, Router};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use sqlx::QueryBuilder;
use utoipa::{IntoParams, ToSchema};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;
use provider_rules::normalize_provider_name;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/webhooks/billing", post(post_billing_webhook))
        .route(
            "/api/v1/webhooks/billing/events",
            get(list_billing_webhook_events),
        )
}

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

#[derive(Debug, Deserialize, Default, IntoParams, ToSchema)]
#[into_params(parameter_in = Query)]
struct BillingEventsQuery {
    informational_event: Option<bool>,
    provider: Option<String>,
    raw_event_id: Option<String>,
    raw_event_id_prefix: Option<String>,
    event_type: Option<String>,
    provider_event_id: Option<String>,
    provider_event_id_prefix: Option<String>,
    event_created_from: Option<String>,
    event_created_to: Option<String>,
    created_from: Option<String>,
    created_to: Option<String>,
    id_min: Option<i64>,
    id_max: Option<i64>,
    sort: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
}

#[derive(Debug, Serialize, FromRow, ToSchema)]
struct BillingWebhookEventItem {
    id: i64,
    provider_event_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    provider: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    raw_event_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    event_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    event_created_at: Option<DateTime<Utc>>,
    is_informational_event: bool,
    created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
struct BillingWebhookEventsResponse {
    items: Vec<BillingWebhookEventItem>,
    total: i64,
    limit: i64,
    offset: i64,
    has_more: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    next_offset: Option<i64>,
}

fn parse_query_ts(raw: &str, field: &str) -> Result<DateTime<Utc>, ApiError> {
    DateTime::parse_from_rfc3339(raw.trim())
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(|_| ApiError::BadRequest(format!("{field} must be RFC3339 timestamp")))
}

fn parse_query_text_non_empty(raw: &str, field: &str, max_len: usize) -> Result<String, ApiError> {
    let v = raw.trim();
    if v.is_empty() {
        return Err(ApiError::BadRequest(format!("{field} must be non-empty")));
    }
    Ok(v.chars().take(max_len).collect())
}

fn parse_sort(raw: Option<&str>) -> Result<&'static str, ApiError> {
    let Some(raw) = raw else {
        return Ok("id DESC");
    };
    match raw.trim().to_ascii_lowercase().as_str() {
        "id_desc" => Ok("id DESC"),
        "id_asc" => Ok("id ASC"),
        _ => Err(ApiError::BadRequest(
            "sort must be one of: id_desc, id_asc".into(),
        )),
    }
}

fn parse_provider_filter(raw: Option<&str>) -> Result<Option<String>, ApiError> {
    let Some(raw) = raw else {
        return Ok(None);
    };
    let normalized = normalize_provider_name(raw)
        .ok_or_else(|| ApiError::BadRequest("provider must be non-empty".into()))?;
    match normalized.as_str() {
        "stripe" | "alipay" | "paddle" => Ok(Some(normalized)),
        _ => Err(ApiError::BadRequest(
            "provider must be one of: stripe, alipay, paddle".into(),
        )),
    }
}

fn validate_time_range(
    from: Option<DateTime<Utc>>,
    to: Option<DateTime<Utc>>,
    from_field: &str,
    to_field: &str,
) -> Result<(), ApiError> {
    if let (Some(from), Some(to)) = (from, to) {
        if from > to {
            return Err(ApiError::BadRequest(format!(
                "{from_field} must be less than or equal to {to_field}"
            )));
        }
    }
    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/v1/webhooks/billing/events",
    operation_id = "listBillingWebhookEventsV1",
    tag = "webhooks",
    params(BillingEventsQuery),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "OK", body = BillingWebhookEventsResponse),
        (status = 400, description = "Bad filter parameters", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Listing disabled", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    )
)]
async fn list_billing_webhook_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<BillingEventsQuery>,
) -> Result<Json<BillingWebhookEventsResponse>, ApiError> {
    // Require a valid user JWT first (same gate as other read APIs).
    let _ = require_user_uuid(&state, &headers)?;

    // Global webhook audit log — not tenant-scoped; off by default (ops/staging only).
    if std::env::var("BILLING_WEBHOOK_EVENTS_LIST_ENABLED")
        .ok()
        .as_deref()
        != Some("1")
    {
        return Err(ApiError::Forbidden(
            "billing webhook event listing is disabled; set BILLING_WEBHOOK_EVENTS_LIST_ENABLED=1 to enable (ops/audit only)."
                .into(),
        ));
    }

    let limit = q.limit.unwrap_or(50).clamp(1, 200);
    let offset = q.offset.unwrap_or(0).max(0);
    let provider = parse_provider_filter(q.provider.as_deref())?;
    let raw_event_id = q
        .raw_event_id
        .as_deref()
        .map(|s| parse_query_text_non_empty(s, "raw_event_id", 256))
        .transpose()?;
    let raw_event_id_prefix = q
        .raw_event_id_prefix
        .as_deref()
        .map(|s| parse_query_text_non_empty(s, "raw_event_id_prefix", 256))
        .transpose()?;
    let event_type = q
        .event_type
        .as_deref()
        .map(|s| parse_query_text_non_empty(s, "event_type", 128))
        .transpose()?;
    let provider_event_id = q
        .provider_event_id
        .as_deref()
        .map(|s| parse_query_text_non_empty(s, "provider_event_id", 256))
        .transpose()?;
    let provider_event_id_prefix = q
        .provider_event_id_prefix
        .as_deref()
        .map(|s| parse_query_text_non_empty(s, "provider_event_id_prefix", 256))
        .transpose()?;
    let event_created_from = q
        .event_created_from
        .as_deref()
        .map(|s| parse_query_ts(s, "event_created_from"))
        .transpose()?;
    let event_created_to = q
        .event_created_to
        .as_deref()
        .map(|s| parse_query_ts(s, "event_created_to"))
        .transpose()?;
    let created_from = q
        .created_from
        .as_deref()
        .map(|s| parse_query_ts(s, "created_from"))
        .transpose()?;
    let created_to = q
        .created_to
        .as_deref()
        .map(|s| parse_query_ts(s, "created_to"))
        .transpose()?;
    validate_time_range(
        event_created_from,
        event_created_to,
        "event_created_from",
        "event_created_to",
    )?;
    validate_time_range(created_from, created_to, "created_from", "created_to")?;
    let id_min = q.id_min;
    let id_max = q.id_max;
    if let (Some(min), Some(max)) = (id_min, id_max) {
        if min > max {
            return Err(ApiError::BadRequest(
                "id_min must be less than or equal to id_max".into(),
            ));
        }
    }
    let sort = parse_sort(q.sort.as_deref())?;
    let pool = state.require_pool()?;

    let mut count_qb = QueryBuilder::new(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_billing_webhook_event
        "#,
    );
    let mut has_where = false;
    if let Some(informational) = q.informational_event {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("is_informational_event = ");
        count_qb.push_bind(informational);
        has_where = true;
    }
    if let Some(provider) = provider.clone() {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("provider = ");
        count_qb.push_bind(provider);
        has_where = true;
    }
    if let Some(raw_event_id) = raw_event_id.clone() {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("raw_event_id = ");
        count_qb.push_bind(raw_event_id);
        has_where = true;
    }
    if let Some(prefix) = raw_event_id_prefix.clone() {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("raw_event_id LIKE ");
        count_qb.push_bind(format!("{prefix}%"));
        has_where = true;
    }
    if let Some(event_type) = event_type.clone() {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("event_type = ");
        count_qb.push_bind(event_type);
        has_where = true;
    }
    if let Some(provider_event_id) = provider_event_id.clone() {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("provider_event_id = ");
        count_qb.push_bind(provider_event_id);
        has_where = true;
    }
    if let Some(prefix) = provider_event_id_prefix.clone() {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("provider_event_id LIKE ");
        count_qb.push_bind(format!("{prefix}%"));
        has_where = true;
    }
    if let Some(from) = event_created_from {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("event_created_at >= ");
        count_qb.push_bind(from);
        has_where = true;
    }
    if let Some(to) = event_created_to {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("event_created_at <= ");
        count_qb.push_bind(to);
        has_where = true;
    }
    if let Some(from) = created_from {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("created_at >= ");
        count_qb.push_bind(from);
        has_where = true;
    }
    if let Some(to) = created_to {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("created_at <= ");
        count_qb.push_bind(to);
        has_where = true;
    }
    if let Some(min) = id_min {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("id >= ");
        count_qb.push_bind(min);
        has_where = true;
    }
    if let Some(max) = id_max {
        count_qb.push(if has_where { " AND " } else { " WHERE " });
        count_qb.push("id <= ");
        count_qb.push_bind(max);
    }
    let total: i64 = count_qb
        .build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut qb = QueryBuilder::new(
        r#"
        SELECT
          id,
          provider_event_id,
          provider,
          raw_event_id,
          event_type,
          event_created_at,
          is_informational_event,
          created_at
        FROM app_billing_webhook_event
        "#,
    );
    let mut has_where = false;
    if let Some(informational) = q.informational_event {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("is_informational_event = ");
        qb.push_bind(informational);
        has_where = true;
    }
    if let Some(provider) = provider {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("provider = ");
        qb.push_bind(provider);
        has_where = true;
    }
    if let Some(raw_event_id) = raw_event_id {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("raw_event_id = ");
        qb.push_bind(raw_event_id);
        has_where = true;
    }
    if let Some(prefix) = raw_event_id_prefix {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("raw_event_id LIKE ");
        qb.push_bind(format!("{prefix}%"));
        has_where = true;
    }
    if let Some(event_type) = event_type {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("event_type = ");
        qb.push_bind(event_type);
        has_where = true;
    }
    if let Some(provider_event_id) = provider_event_id {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("provider_event_id = ");
        qb.push_bind(provider_event_id);
        has_where = true;
    }
    if let Some(prefix) = provider_event_id_prefix {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("provider_event_id LIKE ");
        qb.push_bind(format!("{prefix}%"));
        has_where = true;
    }
    if let Some(from) = event_created_from {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("event_created_at >= ");
        qb.push_bind(from);
        has_where = true;
    }
    if let Some(to) = event_created_to {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("event_created_at <= ");
        qb.push_bind(to);
        has_where = true;
    }
    if let Some(from) = created_from {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("created_at >= ");
        qb.push_bind(from);
        has_where = true;
    }
    if let Some(to) = created_to {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("created_at <= ");
        qb.push_bind(to);
        has_where = true;
    }
    if let Some(min) = id_min {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("id >= ");
        qb.push_bind(min);
        has_where = true;
    }
    if let Some(max) = id_max {
        qb.push(if has_where { " AND " } else { " WHERE " });
        qb.push("id <= ");
        qb.push_bind(max);
    }
    qb.push(" ORDER BY ");
    qb.push(sort);
    qb.push(" LIMIT ");
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);

    let items = qb
        .build_query_as::<BillingWebhookEventItem>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let fetched = i64::try_from(items.len()).unwrap_or(0);
    let next = offset.saturating_add(fetched);
    let has_more = next < total;

    Ok(Json(BillingWebhookEventsResponse {
        items,
        total,
        limit,
        offset,
        has_more,
        next_offset: if has_more { Some(next) } else { None },
    }))
}
