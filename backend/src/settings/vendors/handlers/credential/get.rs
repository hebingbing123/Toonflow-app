use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::common::require_pool;
use super::validate::require_nonempty_vendor_id;
use crate::settings::vendors::dto::CredentialResponse;

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
    let vendor_id = require_nonempty_vendor_id(&vendor_id)?;
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
