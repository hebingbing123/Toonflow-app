//! `GET /api/v1/webhooks/billing/events` — 审计查询端点。

use axum::extract::{Query, State};
use axum::http::HeaderMap;
use axum::Json;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use sqlx::QueryBuilder;
use utoipa::{IntoParams, ToSchema};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::provider_rules::normalize_provider_name;

// ── Query params ─────────────────────────────────────────────────────────────

#[derive(Debug, Deserialize, Default, IntoParams, ToSchema)]
#[into_params(parameter_in = Query)]
pub(super) struct BillingEventsQuery {
    pub informational_event: Option<bool>,
    pub provider: Option<String>,
    pub raw_event_id: Option<String>,
    pub raw_event_id_prefix: Option<String>,
    pub event_type: Option<String>,
    pub provider_event_id: Option<String>,
    pub provider_event_id_prefix: Option<String>,
    pub event_created_from: Option<String>,
    pub event_created_to: Option<String>,
    pub created_from: Option<String>,
    pub created_to: Option<String>,
    pub id_min: Option<i64>,
    pub id_max: Option<i64>,
    pub sort: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// ── Response types ────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, FromRow, ToSchema)]
pub(super) struct BillingWebhookEventItem {
    pub id: i64,
    pub provider_event_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub provider: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub raw_event_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub event_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub event_created_at: Option<DateTime<Utc>>,
    pub is_informational_event: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
pub(super) struct BillingWebhookEventsResponse {
    pub items: Vec<BillingWebhookEventItem>,
    pub total: i64,
    pub limit: i64,
    pub offset: i64,
    pub has_more: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub next_offset: Option<i64>,
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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

// ── Handler ───────────────────────────────────────────────────────────────────

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
#[allow(unused_assignments)]
pub(super) async fn list_billing_webhook_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<BillingEventsQuery>,
) -> Result<Json<BillingWebhookEventsResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;

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

    // ── COUNT query ───────────────────────────────────────────────────────────
    let mut count_qb = QueryBuilder::new("SELECT COUNT(*)::bigint FROM app_billing_webhook_event");
    let mut has_where = false;
    macro_rules! push_filter {
        ($qb:expr, $has_where:expr, $col:literal, $op:literal, $val:expr) => {{
            $qb.push(if $has_where { " AND " } else { " WHERE " });
            $qb.push(concat!($col, " ", $op, " "));
            $qb.push_bind($val);
            $has_where = true;
        }};
    }
    if let Some(v) = q.informational_event {
        push_filter!(count_qb, has_where, "is_informational_event", "=", v);
    }
    if let Some(v) = provider.clone() {
        push_filter!(count_qb, has_where, "provider", "=", v);
    }
    if let Some(v) = raw_event_id.clone() {
        push_filter!(count_qb, has_where, "raw_event_id", "=", v);
    }
    if let Some(prefix) = raw_event_id_prefix.clone() {
        push_filter!(
            count_qb,
            has_where,
            "raw_event_id",
            "LIKE",
            format!("{prefix}%")
        );
    }
    if let Some(v) = event_type.clone() {
        push_filter!(count_qb, has_where, "event_type", "=", v);
    }
    if let Some(v) = provider_event_id.clone() {
        push_filter!(count_qb, has_where, "provider_event_id", "=", v);
    }
    if let Some(prefix) = provider_event_id_prefix.clone() {
        push_filter!(
            count_qb,
            has_where,
            "provider_event_id",
            "LIKE",
            format!("{prefix}%")
        );
    }
    if let Some(v) = event_created_from {
        push_filter!(count_qb, has_where, "event_created_at", ">=", v);
    }
    if let Some(v) = event_created_to {
        push_filter!(count_qb, has_where, "event_created_at", "<=", v);
    }
    if let Some(v) = created_from {
        push_filter!(count_qb, has_where, "created_at", ">=", v);
    }
    if let Some(v) = created_to {
        push_filter!(count_qb, has_where, "created_at", "<=", v);
    }
    if let Some(v) = id_min {
        push_filter!(count_qb, has_where, "id", ">=", v);
    }
    if let Some(v) = id_max {
        push_filter!(count_qb, has_where, "id", "<=", v);
    }
    let total: i64 = count_qb
        .build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // ── SELECT query ──────────────────────────────────────────────────────────
    let mut qb = QueryBuilder::new(
        r#"SELECT id, provider_event_id, provider, raw_event_id, event_type,
                  event_created_at, is_informational_event, created_at
           FROM app_billing_webhook_event"#,
    );
    let mut has_where = false;
    if let Some(v) = q.informational_event {
        push_filter!(qb, has_where, "is_informational_event", "=", v);
    }
    if let Some(v) = provider {
        push_filter!(qb, has_where, "provider", "=", v);
    }
    if let Some(v) = raw_event_id {
        push_filter!(qb, has_where, "raw_event_id", "=", v);
    }
    if let Some(prefix) = raw_event_id_prefix {
        push_filter!(qb, has_where, "raw_event_id", "LIKE", format!("{prefix}%"));
    }
    if let Some(v) = event_type {
        push_filter!(qb, has_where, "event_type", "=", v);
    }
    if let Some(v) = provider_event_id {
        push_filter!(qb, has_where, "provider_event_id", "=", v);
    }
    if let Some(prefix) = provider_event_id_prefix {
        push_filter!(
            qb,
            has_where,
            "provider_event_id",
            "LIKE",
            format!("{prefix}%")
        );
    }
    if let Some(v) = event_created_from {
        push_filter!(qb, has_where, "event_created_at", ">=", v);
    }
    if let Some(v) = event_created_to {
        push_filter!(qb, has_where, "event_created_at", "<=", v);
    }
    if let Some(v) = created_from {
        push_filter!(qb, has_where, "created_at", ">=", v);
    }
    if let Some(v) = created_to {
        push_filter!(qb, has_where, "created_at", "<=", v);
    }
    if let Some(v) = id_min {
        push_filter!(qb, has_where, "id", ">=", v);
    }
    if let Some(v) = id_max {
        push_filter!(qb, has_where, "id", "<=", v);
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
