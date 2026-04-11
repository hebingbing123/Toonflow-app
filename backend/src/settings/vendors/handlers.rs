//! 提供商设置 HTTP 处理器。
//!
//! 提供商列表、配置和模型测试端点。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use serde_json::json;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST};
use crate::state::AppState;
use crate::vendor::catalog::vendor_catalog_summaries;
use crate::vendor::credential::{encrypt, is_encryption_configured, key_hint};

use super::dto::{
    AddVendorBody, CredentialResponse, DeleteVendorBody, EnableVendorBody, StoreCredentialBody,
    UpdateVendorBody, UpdateVendorCodeBody, UpdateVendorResponse, VendorCodeFromLinkBody,
    VendorModelTestBody, VendorSummaryItem, VendorsSummaryResponse,
};
use super::store::{load_vendor_config, save_vendor_config};
use super::MAX_VENDOR_MODEL_TEST_FIELD_LEN;

pub(super) async fn get_vendors_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<VendorsSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let catalog = vendor_catalog_summaries();

    // Load user config if DB is available
    let user_cfg = if let Some(pool) = state.pool.as_ref() {
        load_vendor_config(pool, uid).await.ok()
    } else {
        None
    };

    let vendors = catalog
        .into_iter()
        .map(|c| {
            let user_config = user_cfg
                .as_ref()
                .and_then(|cfg| cfg.get_vendor(&c.id.to_string()).cloned());
            VendorSummaryItem {
                catalog: c,
                user_config,
            }
        })
        .collect();

    Ok(Json(VendorsSummaryResponse {
        vendors,
        source: "static_catalog_with_user_config",
    }))
}

pub(super) async fn post_vendor_model_test(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VendorModelTestBody>,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let kind = body.kind.to_ascii_lowercase();
    if kind != "text" && kind != "image" && kind != "video" {
        return Err(ApiError::BadRequest(
            "type must be text, image, or video".into(),
        ));
    }
    let model_name = body.model_name.trim();
    let id = body.id.trim();
    if model_name.is_empty() || id.is_empty() {
        return Err(ApiError::BadRequest(
            "modelName and id must be non-empty".into(),
        ));
    }
    if model_name.len() > MAX_VENDOR_MODEL_TEST_FIELD_LEN
        || id.len() > MAX_VENDOR_MODEL_TEST_FIELD_LEN
    {
        return Err(ApiError::BadRequest(format!(
            "modelName and id must be at most {MAX_VENDOR_MODEL_TEST_FIELD_LEN} chars each"
        )));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let payload = json!({
        "source": "settings.vendors.model-test",
        "model_name": model_name,
        "kind": kind,
        "id": id,
    });

    let row =
        enqueue_generation_job(pool, uid, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST, payload).await?;
    Ok(Json(row))
}

pub(super) async fn post_add_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddVendorBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ts_code.trim().is_empty() {
        return Err(ApiError::BadRequest("tsCode must be non-empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Generate a new vendor ID
    let vendor_id = format!(
        "custom-{}",
        Uuid::new_v4()
            .to_string()
            .split('-')
            .next()
            .unwrap_or("vendor")
    );

    // Store custom vendor in vendor_config (metadata only, no code execution)
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

pub(super) async fn post_update_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateVendorBody>,
) -> Result<Json<UpdateVendorResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut cfg = load_vendor_config(pool, uid).await?;
    let entry = cfg.get_or_insert_vendor(vendor_id);
    if let Some(name) = body.display_name {
        entry.display_name = Some(name);
    }
    if !body.selected_models.is_empty() {
        entry.selected_models = body.selected_models;
    }
    if !body.settings.is_empty() {
        // Merge settings - intentionally exclude any key that looks like an API key
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

pub(super) async fn post_delete_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteVendorBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Remove vendor from config
    let mut cfg = load_vendor_config(pool, uid).await?;
    if cfg.vendors.remove(vendor_id).is_none() {
        return Err(ApiError::NotFound);
    }
    save_vendor_config(pool, uid, &cfg).await?;

    // Also delete any stored credentials
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

pub(super) async fn post_enable_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EnableVendorBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = body.id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut cfg = load_vendor_config(pool, uid).await?;
    cfg.set_vendor_enabled(vendor_id, body.enable != 0);
    save_vendor_config(pool, uid, &cfg).await?;

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "enabled": body.enable != 0,
        "message": "Vendor enable state saved"
    })))
}

pub(super) async fn post_update_vendor_code(
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

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Update vendor code in config (store only, no execution)
    let mut cfg = load_vendor_config(pool, uid).await?;
    let entry = cfg.get_or_insert_vendor(vendor_id);
    entry.settings.insert("ts_code".to_string(), body.ts_code);
    save_vendor_config(pool, uid, &cfg).await?;

    Ok(Json(serde_json::json!({
        "vendorId": vendor_id,
        "message": "Vendor code updated (stored, not executed)",
    })))
}

pub(super) async fn post_vendor_code_from_link(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VendorCodeFromLinkBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let link = body.link.trim();
    if link.is_empty() {
        return Err(ApiError::BadRequest("link must be non-empty".into()));
    }

    // Validate link format
    if !link.starts_with("http://") && !link.starts_with("https://") {
        return Err(ApiError::BadRequest(
            "link must be a valid HTTP(S) URL".into(),
        ));
    }

    // For security, we don't actually fetch external links in the backend
    // Instead, we store the link reference and let the frontend/client fetch if needed
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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

pub(super) async fn post_store_credential(
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

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Encrypt credentials
    let api_key_encrypted = body.api_key.as_ref().and_then(|k| encrypt(k));
    let api_secret_encrypted = body.api_secret.as_ref().and_then(|s| encrypt(s));
    let api_token_encrypted = body.api_token.as_ref().and_then(|t| encrypt(t));

    let key_hint_value = body.api_key.as_ref().map(|k| key_hint(k));

    // Upsert credential record
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

#[allow(clippy::type_complexity)]
pub(super) async fn get_credential(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(vendor_id): Path<String>,
) -> Result<Json<CredentialResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = vendor_id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("vendorId must be non-empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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

    let (key_hint, has_secret, has_token) = match row {
        Some((hint, secret, token)) => (hint, secret.is_some(), token.is_some()),
        None => return Err(ApiError::NotFound),
    };

    Ok(Json(CredentialResponse {
        vendor_id: vendor_id.to_string(),
        key_hint,
        has_secret,
        has_token,
        message: "Credential metadata retrieved (keys not exposed via HTTP)",
    }))
}

pub(super) async fn delete_credential(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(vendor_id): Path<String>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let vendor_id = vendor_id.trim();
    if vendor_id.is_empty() {
        return Err(ApiError::BadRequest("vendorId must be non-empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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

pub(super) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings/vendors/summary", get(get_vendors_summary))
        .route(
            "/api/v1/settings/vendors/model-test",
            post(post_vendor_model_test),
        )
        .route("/api/v1/settings/vendors/add", post(post_add_vendor))
        .route("/api/v1/settings/vendors/update", post(post_update_vendor))
        .route("/api/v1/settings/vendors/delete", post(post_delete_vendor))
        .route("/api/v1/settings/vendors/enable", post(post_enable_vendor))
        .route(
            "/api/v1/settings/vendors/update-code",
            post(post_update_vendor_code),
        )
        .route(
            "/api/v1/settings/vendors/code-from-link",
            post(post_vendor_code_from_link),
        )
        .route(
            "/api/v1/settings/vendors/credential",
            post(post_store_credential),
        )
        .route(
            "/api/v1/settings/vendors/credential/{vendor_id}",
            get(get_credential).delete(delete_credential),
        )
}
