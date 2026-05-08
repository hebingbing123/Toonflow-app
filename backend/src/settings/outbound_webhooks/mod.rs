use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{delete, post},
    Json, Router,
};
use base64::Engine;
use hmac::Mac;
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::Sha256;
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OutboundWebhookCreateBody {
    pub url: String,
    #[serde(default)]
    pub secret: Option<String>,
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
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OutboundWebhookListResponse {
    pub items: Vec<OutboundWebhookListItem>,
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

fn sign_toonflow(secret: &[u8], timestamp_unix_secs: u64, body: &[u8]) -> String {
    type HmacSha256 = hmac::Hmac<Sha256>;
    let mut mac = HmacSha256::new_from_slice(secret).expect("hmac secret accepted");
    mac.update(timestamp_unix_secs.to_string().as_bytes());
    mac.update(b".");
    mac.update(body);
    let hex = hex::encode(mac.finalize().into_bytes());
    format!("sha256={hex}")
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
    let secret = body.secret.unwrap_or_default().trim().to_string();
    let secret = if secret.is_empty() {
        generate_secret()
    } else {
        secret
    };

    let id = Uuid::new_v4();

    sqlx::query(
        r#"
        INSERT INTO app_outbound_webhook (id, owner_user_id, url, secret)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(id)
    .bind(user_id)
    .bind(&url)
    .bind(&secret)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(OutboundWebhookCreatedResponse { id, url, secret }))
}

#[derive(Debug, Clone, Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OutboundWebhookListQuery {
    #[serde(default)]
    pub limit: Option<i64>,
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

    let rows = sqlx::query_as::<_, (Uuid, String, chrono::DateTime<chrono::Utc>)>(
        r#"
        SELECT id, url, created_at
        FROM app_outbound_webhook
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

    Ok(Json(OutboundWebhookListResponse {
        items: rows
            .into_iter()
            .map(|(id, url, created_at)| OutboundWebhookListItem {
                id,
                url,
                created_at: created_at.to_rfc3339(),
            })
            .collect(),
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
        DELETE FROM app_outbound_webhook
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
        FROM app_outbound_webhook
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
    let bytes =
        serde_json::to_vec(&payload).map_err(|_| ApiError::BadRequest("bad payload".into()))?;

    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let signature = sign_toonflow(secret.as_bytes(), ts, &bytes);

    let res = state
        .http_client
        .post(&url)
        .header("Content-Type", "application/json")
        .header("X-Toonflow-Timestamp", ts.to_string())
        .header("X-Toonflow-Signature", signature)
        .body(bytes)
        .send()
        .await;

    match res {
        Ok(r) => Ok(Json(OutboundWebhookTestResponse {
            delivered: r.status().is_success(),
            http_status: Some(r.status().as_u16()),
            error: if r.status().is_success() {
                None
            } else {
                Some(format!("HTTP {}", r.status().as_u16()))
            },
        })),
        Err(e) => Ok(Json(OutboundWebhookTestResponse {
            delivered: false,
            http_status: None,
            error: Some(e.to_string()),
        })),
    }
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/webhooks/outbound",
            post(post_outbound_webhook_create).get(get_outbound_webhook_list),
        )
        .route(
            "/api/v1/settings/webhooks/outbound/{id}",
            delete(delete_outbound_webhook),
        )
        .route(
            "/api/v1/settings/webhooks/outbound/{id}/test",
            post(post_outbound_webhook_test),
        )
}
