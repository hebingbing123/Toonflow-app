use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use serde_json::json;
use uuid::Uuid;

use crate::auth::require_jwt_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::storage;
use super::types::{
    ApiKeyAuditListResponse, ApiKeyAuditQuery, ApiKeyCreateBody, ApiKeyCreatedResponse,
    ApiKeyListResponse, ApiKeyRecord, ApiKeyRevokeBody, ApiKeyRotateBody, ApiKeyStatusDto,
};

#[utoipa::path(
    get,
    path = "/api/v1/settings/api-keys",
    operation_id = "getSettingsApiKeysV1",
    tag = "settings",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "OK", body = ApiKeyListResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Database / auth not configured", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_api_keys(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ApiKeyListResponse>, ApiError> {
    let user_id = require_jwt_user_uuid(&state, &headers)?;
    let items = storage::list_api_keys(&state, user_id).await?;
    let active_count = items
        .iter()
        .filter(|item| item.status == ApiKeyStatusDto::Active)
        .count();
    let revoked_count = items.len().saturating_sub(active_count);
    Ok(Json(ApiKeyListResponse {
        items,
        active_count,
        revoked_count,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/api-keys/audit",
    operation_id = "getSettingsApiKeyAuditV1",
    tag = "settings",
    params(ApiKeyAuditQuery),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "OK", body = ApiKeyAuditListResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Database / auth not configured", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_api_key_audit(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ApiKeyAuditQuery>,
) -> Result<Json<ApiKeyAuditListResponse>, ApiError> {
    let user_id = require_jwt_user_uuid(&state, &headers)?;
    let items =
        storage::list_api_key_audit(&state, user_id, query.limit.unwrap_or(50).clamp(1, 200))
            .await?;
    Ok(Json(ApiKeyAuditListResponse { items }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/api-keys",
    operation_id = "postSettingsApiKeyCreateV1",
    tag = "settings",
    request_body(content = ApiKeyCreateBody, content_type = "application/json"),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Created", body = ApiKeyCreatedResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Database / auth not configured", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_create_api_key(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ApiKeyCreateBody>,
) -> Result<Json<ApiKeyCreatedResponse>, ApiError> {
    let user_id = require_jwt_user_uuid(&state, &headers)?;
    let created = storage::create_api_key(&state, user_id, user_id, body).await?;
    Ok(Json(created))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/api-keys/{id}/rotate",
    operation_id = "postSettingsApiKeyRotateV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "API key id")),
    request_body(content = ApiKeyRotateBody, content_type = "application/json"),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Rotated", body = ApiKeyCreatedResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database / auth not configured", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_rotate_api_key(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<ApiKeyRotateBody>,
) -> Result<Json<ApiKeyCreatedResponse>, ApiError> {
    let user_id = require_jwt_user_uuid(&state, &headers)?;
    let rotated = storage::rotate_api_key(&state, user_id, user_id, id, body).await?;
    Ok(Json(rotated))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/api-keys/{id}/revoke",
    operation_id = "postSettingsApiKeyRevokeV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "API key id")),
    request_body(content = ApiKeyRevokeBody, content_type = "application/json"),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Revoked", body = ApiKeyRecord),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database / auth not configured", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_revoke_api_key(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<ApiKeyRevokeBody>,
) -> Result<Json<ApiKeyRecord>, ApiError> {
    let user_id = require_jwt_user_uuid(&state, &headers)?;
    let record =
        storage::update_api_key_status(&state, user_id, user_id, id, "revoked", body.reason)
            .await?;
    Ok(Json(record))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/api-keys/{id}/activate",
    operation_id = "postSettingsApiKeyActivateV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "API key id")),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Activated", body = ApiKeyRecord),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database / auth not configured", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn post_activate_api_key(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ApiKeyRecord>, ApiError> {
    let user_id = require_jwt_user_uuid(&state, &headers)?;
    let record =
        storage::update_api_key_status(&state, user_id, user_id, id, "active", None).await?;
    Ok(Json(record))
}

#[utoipa::path(
    delete,
    path = "/api/v1/settings/api-keys/{id}",
    operation_id = "deleteSettingsApiKeyV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "API key id")),
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Deleted", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Database / auth not configured", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn delete_api_key(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let user_id = require_jwt_user_uuid(&state, &headers)?;
    storage::delete_api_key(&state, user_id, user_id, id).await?;
    Ok(Json(json!({ "deleted": true })))
}
