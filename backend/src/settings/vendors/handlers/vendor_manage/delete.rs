//! 删除 vendor 及关联凭据。

use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::settings::vendors::dto::DeleteVendorBody;
use crate::settings::vendors::store::{load_vendor_config, save_vendor_config};
use crate::state::AppState;

use super::super::common::require_pool;

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/delete",
    operation_id = "postSettingsVendorsDeleteV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_delete_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteVendorBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }

    let pool = require_pool(&state)?;
    let mut cfg = load_vendor_config(pool, uid).await?;
    if cfg.vendors.remove(vendor_id).is_none() {
        return Err(ApiError::NotFound);
    }
    save_vendor_config(pool, uid, &cfg).await?;

    sqlx::query(
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

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "message": "Vendor deleted",
    })))
}
