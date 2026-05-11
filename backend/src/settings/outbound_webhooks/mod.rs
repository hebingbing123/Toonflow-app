use std::collections::BTreeSet;
use std::time::Duration;

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, patch, post},
    Json, Router,
};
use base64::Engine;
use hmac::Mac;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::Sha256;
use sqlx::types::Json as SqlxJson;
use sqlx::PgPool;
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

mod deliver;

pub(crate) use deliver::fire_job_terminal_outbound_webhooks;

/// Platform event types users may subscribe to (plus `test.ping` for manual tests only).
pub const OUTBOUND_WEBHOOK_PLATFORM_EVENT_TYPES: &[&str] = &[
    "job.completed",
    "job.failed",
    "project.created",
    "workspace.member.added",
];

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OutboundWebhookCreateBody {
    pub url: String,
    #[serde(default)]
    pub secret: Option<String>,
    #[serde(default)]
    pub workspace_id: Option<Uuid>,
    /// Subset of `OUTBOUND_WEBHOOK_PLATFORM_EVENT_TYPES`. Empty = subscribe to all four.
    #[serde(default)]
    pub event_types: Option<Vec<String>>,
    #[serde(default)]
    pub enabled: Option<bool>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OutboundWebhookCreatedResponse {
    pub id: Uuid,
    pub url: String,
    /// Returned only once at creation.
    pub secret: String,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OutboundWebhookListItem {
    pub id: Uuid,
    pub url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub workspace_id: Option<Uuid>,
    pub event_types: Vec<String>,
    pub enabled: bool,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OutboundWebhookListResponse {
    pub items: Vec<OutboundWebhookListItem>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OutboundWebhookPatchBody {
    pub url: Option<String>,
    /// When set to non-empty, replaces the signing secret.
    pub secret: Option<String>,
    pub workspace_id: Option<Uuid>,
    pub event_types: Option<Vec<String>>,
    pub enabled: Option<bool>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OutboundWebhookTestBody {
    #[serde(default)]
    pub event_type: Option<String>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OutboundWebhookTestResponse {
    pub delivered: bool,
    pub http_status: Option<u16>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OutboundWebhookDeliveryItem {
    pub id: Uuid,
    pub event_type: String,
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub http_status: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    pub retry_count: i32,
    pub created_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub delivered_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub payload: Option<Value>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OutboundWebhookDeliveryListResponse {
    pub items: Vec<OutboundWebhookDeliveryItem>,
}

#[derive(Debug, Clone, Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OutboundWebhookListQuery {
    #[serde(default)]
    pub limit: Option<i64>,
}

#[derive(Debug, Clone, Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OutboundWebhookDeliveriesQuery {
    #[serde(default)]
    pub limit: Option<i64>,
}

fn validate_url(raw: &str) -> Result<String, ApiError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Err(ApiError::BadRequest("url must be non-empty".into()));
    }
    let parsed = url::Url::parse(trimmed)
        .map_err(|_| ApiError::BadRequest("url must be a valid absolute URL".into()))?;
    match parsed.scheme() {
        "http" | "https" => {}
        _ => {
            return Err(ApiError::BadRequest(
                "url must start with http:// or https://".into(),
            ));
        }
    }
    Ok(trimmed.to_string())
}

fn generate_secret() -> String {
    let bytes: [u8; 32] = rand::random();
    base64::engine::general_purpose::STANDARD_NO_PAD.encode(bytes)
}

pub(super) fn sign_toonflow(secret: &[u8], timestamp_unix_secs: u64, body: &[u8]) -> String {
    type HmacSha256 = hmac::Hmac<Sha256>;
    let mut mac = HmacSha256::new_from_slice(secret).expect("hmac secret accepted");
    mac.update(timestamp_unix_secs.to_string().as_bytes());
    mac.update(b".");
    mac.update(body);
    let hex = hex::encode(mac.finalize().into_bytes());
    format!("sha256={hex}")
}

fn normalize_event_types(raw: Option<Vec<String>>) -> Result<Vec<String>, ApiError> {
    let v: Vec<String> = raw
        .unwrap_or_default()
        .into_iter()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    if v.is_empty() {
        return Ok(OUTBOUND_WEBHOOK_PLATFORM_EVENT_TYPES
            .iter()
            .map(|s| (*s).to_string())
            .collect());
    }
    for x in &v {
        if !OUTBOUND_WEBHOOK_PLATFORM_EVENT_TYPES.contains(&x.as_str()) {
            return Err(ApiError::BadRequest(format!(
                "unknown event type {x:?}; allowed: {}",
                OUTBOUND_WEBHOOK_PLATFORM_EVENT_TYPES.join(", ")
            )));
        }
    }
    let set: BTreeSet<String> = v.into_iter().collect();
    let mut out: Vec<String> = set.into_iter().collect();
    out.sort();
    Ok(out)
}

async fn require_workspace_member(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<(), ApiError> {
    let ok = sqlx::query_scalar::<_, bool>(
        r"
        SELECT EXISTS(
            SELECT 1
            FROM public.app_workspace_member
            WHERE workspace_id = $1
              AND user_id = $2
        )
        ",
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !ok {
        return Err(ApiError::Forbidden(
            "not a member of the selected workspace".into(),
        ));
    }
    Ok(())
}

async fn probe_url_reachable(http: &reqwest::Client, url: &str) -> Result<(), ApiError> {
    let try_head = http.head(url).timeout(Duration::from_secs(5)).send().await;
    if let Ok(resp) = try_head {
        let s = resp.status();
        if s.is_success() || s.is_redirection() || s == StatusCode::METHOD_NOT_ALLOWED {
            return Ok(());
        }
        if s.is_server_error() {
            return Err(ApiError::BadRequest(format!(
                "webhook URL probe failed: HTTP {}",
                s.as_u16()
            )));
        }
    }
    let try_get = http.get(url).timeout(Duration::from_secs(5)).send().await;
    match try_get {
        Ok(resp) => {
            let s = resp.status();
            if s.is_success() || s.is_redirection() {
                Ok(())
            } else {
                Err(ApiError::BadRequest(format!(
                    "webhook URL not reachable: HTTP {}",
                    s.as_u16()
                )))
            }
        }
        Err(e) => Err(ApiError::BadRequest(format!(
            "webhook URL not reachable: {e}"
        ))),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/webhooks/outbound",
    operation_id = "postSettingsOutboundWebhookCreateV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "Created", body = OutboundWebhookCreatedResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_outbound_webhook_create(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<OutboundWebhookCreateBody>,
) -> Result<Json<OutboundWebhookCreatedResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let url = validate_url(&body.url)?;
    probe_url_reachable(&state.http_client, &url).await?;

    let secret = body.secret.unwrap_or_default().trim().to_string();
    let secret = if secret.is_empty() {
        generate_secret()
    } else {
        secret
    };

    if let Some(ws) = body.workspace_id {
        require_workspace_member(pool, user_id, ws).await?;
    }

    let event_types = normalize_event_types(body.event_types.clone())?;
    let enabled = body.enabled.unwrap_or(true);
    let id = Uuid::new_v4();

    sqlx::query(
        r#"
        INSERT INTO public.app_outbound_webhook (
            id, owner_user_id, url, secret, workspace_id, event_types, enabled, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
        "#,
    )
    .bind(id)
    .bind(user_id)
    .bind(&url)
    .bind(&secret)
    .bind(body.workspace_id)
    .bind(SqlxJson(&event_types))
    .bind(enabled)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(OutboundWebhookCreatedResponse { id, url, secret }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/webhooks/outbound",
    operation_id = "getSettingsOutboundWebhookListV1",
    tag = "settings",
    params(OutboundWebhookListQuery),
    responses(
        (status = 200, description = "OK", body = OutboundWebhookListResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_outbound_webhook_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<OutboundWebhookListQuery>,
) -> Result<Json<OutboundWebhookListResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let limit = q.limit.unwrap_or(50).clamp(1, 200);

    let rows = sqlx::query_as::<
        _,
        (
            Uuid,
            String,
            Option<Uuid>,
            Value,
            bool,
            chrono::DateTime<chrono::Utc>,
            chrono::DateTime<chrono::Utc>,
        ),
    >(
        r#"
        SELECT id, url, workspace_id, event_types, enabled, created_at, updated_at
        FROM public.app_outbound_webhook
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        LIMIT $2
        "#,
    )
    .bind(user_id)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut items = Vec::with_capacity(rows.len());
    for (id, url, workspace_id, et_val, enabled, created_at, updated_at) in rows {
        let event_types: Vec<String> = serde_json::from_value(et_val).unwrap_or_default();
        items.push(OutboundWebhookListItem {
            id,
            url,
            workspace_id,
            event_types,
            enabled,
            created_at: created_at.to_rfc3339(),
            updated_at: updated_at.to_rfc3339(),
        });
    }

    Ok(Json(OutboundWebhookListResponse { items }))
}

#[utoipa::path(
    patch,
    path = "/api/v1/settings/webhooks/outbound/{id}",
    operation_id = "patchSettingsOutboundWebhookV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "Webhook id")),
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "Updated", body = OutboundWebhookListItem),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_outbound_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<OutboundWebhookPatchBody>,
) -> Result<Json<OutboundWebhookListItem>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let row = sqlx::query_as::<_, (String, String, Option<Uuid>, Value, bool)>(
        r#"
        SELECT url, secret, workspace_id, event_types, enabled
        FROM public.app_outbound_webhook
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((mut url, mut secret, mut workspace_id, et_val, mut enabled)) = row else {
        return Err(ApiError::NotFound);
    };

    if let Some(u) = body.url.as_ref() {
        url = validate_url(u)?;
        probe_url_reachable(&state.http_client, &url).await?;
    }
    if let Some(s) = body.secret.as_ref() {
        let t = s.trim();
        if !t.is_empty() {
            secret = t.to_string();
        }
    }
    if let Some(ws) = body.workspace_id {
        require_workspace_member(pool, user_id, ws).await?;
        workspace_id = Some(ws);
    }
    let mut event_types: Vec<String> = serde_json::from_value(et_val).unwrap_or_default();
    if let Some(et) = body.event_types.clone() {
        event_types = normalize_event_types(Some(et))?;
    }
    if let Some(en) = body.enabled {
        enabled = en;
    }

    let updated =
        sqlx::query_as::<_, (chrono::DateTime<chrono::Utc>, chrono::DateTime<chrono::Utc>)>(
            r#"
        UPDATE public.app_outbound_webhook
        SET
            url = $3,
            secret = $4,
            workspace_id = $5,
            event_types = $6,
            enabled = $7,
            updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2
        RETURNING created_at, updated_at
        "#,
        )
        .bind(id)
        .bind(user_id)
        .bind(&url)
        .bind(&secret)
        .bind(workspace_id)
        .bind(SqlxJson(&event_types))
        .bind(enabled)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((created_at, updated_at)) = updated else {
        return Err(ApiError::NotFound);
    };

    Ok(Json(OutboundWebhookListItem {
        id,
        url,
        workspace_id,
        event_types,
        enabled,
        created_at: created_at.to_rfc3339(),
        updated_at: updated_at.to_rfc3339(),
    }))
}

#[utoipa::path(
    delete,
    path = "/api/v1/settings/webhooks/outbound/{id}",
    operation_id = "deleteSettingsOutboundWebhookV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "Webhook id")),
    responses(
        (status = 200, description = "Deleted", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_outbound_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let deleted = sqlx::query_scalar::<_, i64>(
        r#"
        DELETE FROM public.app_outbound_webhook
        WHERE id = $1 AND owner_user_id = $2
        RETURNING 1
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if deleted.is_none() {
        return Err(ApiError::NotFound);
    }

    Ok(Json(json!({"deleted": true})))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/webhooks/outbound/{id}/test",
    operation_id = "postSettingsOutboundWebhookTestV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "Webhook id")),
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "Test attempted", body = OutboundWebhookTestResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_outbound_webhook_test(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<OutboundWebhookTestBody>,
) -> Result<Json<OutboundWebhookTestResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let row = sqlx::query_as::<_, (String, String)>(
        r#"
        SELECT url, secret
        FROM public.app_outbound_webhook
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((url, secret)) = row else {
        return Err(ApiError::NotFound);
    };

    let event_type = body
        .event_type
        .unwrap_or_else(|| "test.ping".to_string())
        .trim()
        .to_string();
    if event_type.is_empty() {
        return Err(ApiError::BadRequest("eventType must be non-empty".into()));
    }

    let payload = json!({
        "id": Uuid::new_v4().to_string(),
        "type": event_type,
        "createdAt": chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
        "data": {"message": "toonflow outbound webhook test"}
    });

    let attempt = deliver::deliver_outbound_event(
        &state.http_client,
        pool,
        id,
        user_id,
        &url,
        &secret,
        &event_type,
        &payload,
    )
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(OutboundWebhookTestResponse {
        delivered: attempt.delivered,
        http_status: attempt.http_status,
        error: attempt.error,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/webhooks/outbound/{id}/deliveries",
    operation_id = "getSettingsOutboundWebhookDeliveriesV1",
    tag = "settings",
    params(
        ("id" = Uuid, Path, description = "Webhook id"),
        OutboundWebhookDeliveriesQuery
    ),
    responses(
        (status = 200, description = "OK", body = OutboundWebhookDeliveryListResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_outbound_webhook_deliveries(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Query(q): Query<OutboundWebhookDeliveriesQuery>,
) -> Result<Json<OutboundWebhookDeliveryListResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let exists = sqlx::query_scalar::<_, bool>(
        r"
        SELECT EXISTS(
            SELECT 1 FROM public.app_outbound_webhook WHERE id = $1 AND owner_user_id = $2
        )
        ",
    )
    .bind(id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !exists {
        return Err(ApiError::NotFound);
    }

    let limit = q.limit.unwrap_or(50).clamp(1, 200);

    let rows = sqlx::query_as::<_, (Uuid, String, String, Option<i32>, Option<String>, i32, chrono::DateTime<chrono::Utc>, Option<chrono::DateTime<chrono::Utc>>, Value)>(
        r#"
        SELECT id, event_type, status, http_status, error, retry_count, created_at, delivered_at, payload
        FROM public.app_outbound_webhook_delivery
        WHERE webhook_id = $1 AND owner_user_id = $2
        ORDER BY created_at DESC
        LIMIT $3
        "#,
    )
    .bind(id)
    .bind(user_id)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = rows
        .into_iter()
        .map(
            |(
                did,
                event_type,
                status,
                http_status,
                error,
                retry_count,
                created_at,
                delivered_at,
                payload,
            )| {
                OutboundWebhookDeliveryItem {
                    id: did,
                    event_type,
                    status,
                    http_status,
                    error,
                    retry_count,
                    created_at: created_at.to_rfc3339(),
                    delivered_at: delivered_at.map(|d| d.to_rfc3339()),
                    payload: Some(payload),
                }
            },
        )
        .collect();

    Ok(Json(OutboundWebhookDeliveryListResponse { items }))
}

fn outbound_settings_router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/webhooks/outbound",
            post(post_outbound_webhook_create).get(get_outbound_webhook_list),
        )
        .route(
            "/api/v1/settings/webhooks/outbound/{id}",
            patch(patch_outbound_webhook).delete(delete_outbound_webhook),
        )
        .route(
            "/api/v1/settings/webhooks/outbound/{id}/test",
            post(post_outbound_webhook_test),
        )
        .route(
            "/api/v1/settings/webhooks/outbound/{id}/deliveries",
            get(get_outbound_webhook_deliveries),
        )
}

/// Alias routes matching platform Phase-2 naming (`GET/POST /api/v1/webhooks`, …) alongside settings paths.
fn outbound_public_alias_router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/webhooks",
            post(post_outbound_webhook_create).get(get_outbound_webhook_list),
        )
        .route(
            "/api/v1/webhooks/{id}",
            patch(patch_outbound_webhook).delete(delete_outbound_webhook),
        )
        .route(
            "/api/v1/webhooks/{id}/test",
            post(post_outbound_webhook_test),
        )
        .route(
            "/api/v1/webhooks/{id}/deliveries",
            get(get_outbound_webhook_deliveries),
        )
}

pub fn router() -> Router<AppState> {
    Router::new()
        .merge(outbound_settings_router())
        .merge(outbound_public_alias_router())
}
