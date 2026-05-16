use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::helpers::not_implemented_i18n;
use crate::error::ApiError;
use crate::state::AppState;
use crate::vendor::credential::{encrypt, is_encryption_configured, key_hint};

use super::super::common::require_pool;
use super::validate::require_nonempty_vendor_id;
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
    let vendor_id = require_nonempty_vendor_id(&body.vendor_id)?;

    if !is_encryption_configured() {
        return Err(not_implemented_i18n(
            "Credential encryption not configured (set TOONFLOW_VENDOR_CREDENTIAL_KEY)",
            "凭据加密未配置（请设置 TOONFLOW_VENDOR_CREDENTIAL_KEY）",
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
