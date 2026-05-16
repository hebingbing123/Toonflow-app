//! `GET /api/v1/webhooks/billing/events` — 审计查询端点。

mod filters;
mod query_builder;

use axum::extract::{Query, State};
use axum::http::HeaderMap;
use axum::Json;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::{IntoParams, ToSchema};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use filters::{
    parse_provider_filter, parse_query_text_non_empty, parse_query_ts, parse_sort,
    validate_time_range,
};
use query_builder::{build_count_query, build_items_query, EventFilters};

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

    if let (Some(min), Some(max)) = (q.id_min, q.id_max) {
        if min > max {
            return Err(crate::error::bad_request_i18n(
                "id_min must be less than or equal to id_max",
                "id_min 必须小于或等于 id_max",
            ));
        }
    }

    let sort = parse_sort(q.sort.as_deref())?;
    let pool = state.require_pool()?;

    let filters = EventFilters {
        informational_event: q.informational_event,
        provider,
        raw_event_id,
        raw_event_id_prefix,
        event_type,
        provider_event_id,
        provider_event_id_prefix,
        event_created_from,
        event_created_to,
        created_from,
        created_to,
        id_min: q.id_min,
        id_max: q.id_max,
    };

    let total: i64 = build_count_query(&filters)
        .build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = build_items_query(&filters, sort, limit, offset)
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
