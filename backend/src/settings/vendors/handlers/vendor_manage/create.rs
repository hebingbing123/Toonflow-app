//! 新增自定义或链接型 vendor。

use axum::{extract::State, http::HeaderMap, Json};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::settings::vendors::dto::{AddVendorBody, VendorCodeFromLinkBody};
use crate::settings::vendors::store::{load_vendor_config, save_vendor_config};
use crate::state::AppState;

use super::super::common::require_pool;

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
