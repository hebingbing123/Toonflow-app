use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;
use crate::vendor::credential::{encrypt, is_encryption_configured, key_hint};

use super::common::require_pool;
use crate::settings::vendors::dto::{CredentialResponse, StoreCredentialBody};

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/credential",
    operation_id = "storeVendorCredentialV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 501, description = "Not implemented", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_store_credential(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoreCredentialBody>,
) -> Result<Json<CredentialResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.vendor_id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("vendorId must be non-empty".into()));
    }

    if !is_encryption_configured() {
        return Err(ApiError::NotImplemented(
            "Credential encryption not configured (set TOONFLOW_VENDOR_CREDENTIAL_KEY)".into(),
        ));
    }

    let pool = require_pool(&state)?;
    let api_key_encrypted = body.api_key.as_ref().and_then(|k| encrypt(k));
    let api_secret_encrypted = body.api_secret.as_ref().and_then(|s| encrypt(s));
    let api_token_encrypted = body.api_token.as_ref().and_then(|t| encrypt(t));
    let key_hint_value = body.api_key.as_ref().map(|k| key_hint(k));

    sqlx::query(
        r#"
        INSERT INTO app_vendor_credential (
            owner_user_id, vendor_id, api_key_encrypted, api_secret_encrypted, 
            api_token_encrypted, key_hint, metadata, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb, NOW())
        ON CONFLICT (owner_user_id, vendor_id) 
        DO UPDATE SET 
            api_key_encrypted = COALESCE($3, app_vendor_credential.api_key_encrypted),
            api_secret_encrypted = COALESCE($4, app_vendor_credential.api_secret_encrypted),
            api_token_encrypted = COALESCE($5, app_vendor_credential.api_token_encrypted),
            key_hint = COALESCE($6, app_vendor_credential.key_hint),
            updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(vendor_id)
    .bind(api_key_encrypted)
    .bind(api_secret_encrypted)
    .bind(api_token_encrypted)
    .bind(key_hint_value.clone())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(CredentialResponse {
        vendor_id: vendor_id.to_string(),
        key_hint: key_hint_value,
        has_secret: body.api_secret.is_some(),
        has_token: body.api_token.is_some(),
        message: "Credential stored securely",
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/vendors/credential/{vendor_id}",
    operation_id = "getVendorCredentialV1",
    tag = "settings",
    params(
        ("vendor_id" = String, Path, description = "Vendor id")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
#[allow(clippy::type_complexity)]
pub(crate) async fn get_credential(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(vendor_id): Path<String>,
) -> Result<Json<CredentialResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = vendor_id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("vendorId must be non-empty".into()));
    }
    let pool = require_pool(&state)?;

    let row: Option<(Option<String>, Option<Vec<u8>>, Option<Vec<u8>>)> = sqlx::query_as(
        r#"
        SELECT key_hint, api_secret_encrypted, api_token_encrypted
        FROM app_vendor_credential
        WHERE owner_user_id = $1 AND vendor_id = $2
        "#,
    )
    .bind(uid)
    .bind(vendor_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (key_hint, secret, token) = row.ok_or(ApiError::NotFound)?;
    let has_secret = secret.is_some();
    let has_token = token.is_some();

    Ok(Json(CredentialResponse {
        vendor_id: vendor_id.to_string(),
        key_hint,
        has_secret,
        has_token,
        message: "Credential metadata retrieved (keys not exposed via HTTP)",
    }))
}

#[utoipa::path(
    delete,
    path = "/api/v1/settings/vendors/credential/{vendor_id}",
    operation_id = "deleteVendorCredentialV1",
    tag = "settings",
    params(
        ("vendor_id" = String, Path, description = "Vendor id")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_credential(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(vendor_id): Path<String>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = vendor_id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("vendorId must be non-empty".into()));
    }
    let pool = require_pool(&state)?;

    let result = sqlx::query(
        r#"
        DELETE FROM app_vendor_credential
        WHERE owner_user_id = $1 AND vendor_id = $2
        "#,
    )
    .bind(uid)
    .bind(vendor_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "message": "Credential deleted"
    })))
}
