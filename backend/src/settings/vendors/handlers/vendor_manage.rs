use axum::{extract::State, http::HeaderMap, Json};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::common::require_pool;
use crate::settings::vendors::dto::{
    AddVendorBody, DeleteVendorBody, EnableVendorBody, UpdateVendorBody, UpdateVendorCodeBody,
    UpdateVendorResponse, VendorCodeFromLinkBody,
};
use crate::settings::vendors::store::{load_vendor_config, save_vendor_config};

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/add",
    operation_id = "postSettingsVendorsAddV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_add_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddVendorBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ts_code.trim().is_empty() {
        return Err(ApiError::BadRequest("tsCode must be non-empty".into()));
    }
    let pool = require_pool(&state)?;

    let vendor_id = format!(
        "custom-{}",
        Uuid::new_v4()
            .to_string()
            .split('-')
            .next()
            .unwrap_or("vendor")
    );

    let mut cfg = load_vendor_config(pool, uid).await?;
    let entry = cfg.get_or_insert_vendor(&vendor_id);
    entry.display_name = Some(format!("Custom Vendor {}", &vendor_id[..8]));
    entry.settings.insert("ts_code".to_string(), body.ts_code);
    entry
        .settings
        .insert("is_custom".to_string(), "true".to_string());
    save_vendor_config(pool, uid, &cfg).await?;

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "message": "Custom vendor added (code stored, not executed)",
    })))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/update",
    operation_id = "postSettingsVendorsUpdateV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_update_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateVendorBody>,
) -> Result<Json<UpdateVendorResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }
    let pool = require_pool(&state)?;

    let mut cfg = load_vendor_config(pool, uid).await?;
    let entry = cfg.get_or_insert_vendor(vendor_id);
    if let Some(name) = body.display_name {
        entry.display_name = Some(name);
    }
    if !body.selected_models.is_empty() {
        entry.selected_models = body.selected_models;
    }
    if !body.settings.is_empty() {
        for (k, v) in body.settings {
            let key_lower = k.to_lowercase();
            if !key_lower.contains("key")
                && !key_lower.contains("secret")
                && !key_lower.contains("token")
                && !key_lower.contains("password")
            {
                entry.settings.insert(k, v);
            }
        }
    }
    save_vendor_config(pool, uid, &cfg).await?;

    Ok(Json(UpdateVendorResponse {
        vendor_id: vendor_id.to_string(),
        message: "Vendor settings saved (API keys excluded)",
    }))
}

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

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/enable",
    operation_id = "postSettingsVendorsEnableV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_enable_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EnableVendorBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }
    let pool = require_pool(&state)?;

    let mut cfg = load_vendor_config(pool, uid).await?;
    cfg.set_vendor_enabled(vendor_id, body.enable != 0);
    save_vendor_config(pool, uid, &cfg).await?;

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "enabled": body.enable != 0,
        "message": "Vendor enable state saved"
    })))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/update-code",
    operation_id = "postSettingsVendorsUpdateCodeV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_update_vendor_code(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateVendorCodeBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }
    if body.ts_code.trim().is_empty() {
        return Err(ApiError::BadRequest("tsCode must be non-empty".into()));
    }

    let pool = require_pool(&state)?;
    let mut cfg = load_vendor_config(pool, uid).await?;
    let entry = cfg.get_or_insert_vendor(vendor_id);
    entry.settings.insert("ts_code".to_string(), body.ts_code);
    save_vendor_config(pool, uid, &cfg).await?;

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "message": "Vendor code updated (stored, not executed)",
    })))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/code-from-link",
    operation_id = "postSettingsVendorsCodeFromLinkV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_vendor_code_from_link(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VendorCodeFromLinkBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let link = body.link.trim();
    if link.is_empty() {
        return Err(ApiError::BadRequest("link must be non-empty".into()));
    }
    if !link.starts_with("http://") && !link.starts_with("https://") {
        return Err(ApiError::BadRequest(
            "link must be a valid HTTP(S) URL".into(),
        ));
    }

    let pool = require_pool(&state)?;
    let vendor_id = format!(
        "linked-{}",
        Uuid::new_v4()
            .to_string()
            .split('-')
            .next()
            .unwrap_or("vendor")
    );

    let mut cfg = load_vendor_config(pool, uid).await?;
    let entry = cfg.get_or_insert_vendor(&vendor_id);
    entry.display_name = Some(format!("Linked Vendor {}", &vendor_id[..8]));
    entry
        .settings
        .insert("code_link".to_string(), link.to_string());
    entry
        .settings
        .insert("is_linked".to_string(), "true".to_string());
    save_vendor_config(pool, uid, &cfg).await?;

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "link": link,
        "message": "Vendor code link stored (fetch and execution on client side)",
    })))
}
