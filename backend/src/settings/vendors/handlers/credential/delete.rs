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
    let vendor_id = require_nonempty_vendor_id(&vendor_id)?;
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
