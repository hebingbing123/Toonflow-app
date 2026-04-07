//! Legacy **`POST /api/setting/vendorConfig/getVendorList`** returned SQLite **`o_vendorConfig`** rows (including **`inputValues`** secrets).
//! SaaS: **`GET …/vendors/summary`** merges static catalog with per-user **`vendor_config`** from `app_user_profile`.
//! **`POST …/vendors/enable`** persists enable/disable state; **`POST …/vendors/update`** persists display name and settings (no API keys).
//! **`POST …/model-test`** validates the legacy body, enqueues **`settings.vendor.model_test`**; worker fails until a live probe exists.
//! **`addVendor`** / **`deleteVendor`** / **`updateCode`** / **`getCodeByLink`**: validate then **501** (no custom vendor creation, no TS/vm2 execution, no outbound fetch).
//! API keys (`inputValues`) are intentionally NOT stored; use server env or vault.

use std::collections::HashMap;

use axum::{
    extract::State,
    http::HeaderMap,
    response::Response,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST};
use crate::models_catalog::vendor_catalog_summaries;
use crate::state::{AppState, VendorConfig};
use crate::vendor_credential::{encrypt, is_encryption_configured, key_hint};
use uuid::Uuid;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct VendorSummaryItem {
    #[serde(flatten)]
    catalog: crate::models_catalog::VendorCatalogSummary,
    /// User configuration for this vendor (if any).
    #[serde(skip_serializing_if = "Option::is_none")]
    user_config: Option<crate::state::VendorConfigEntry>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct VendorsSummaryResponse {
    vendors: Vec<VendorSummaryItem>,
    /// **`static_catalog`** merged with per-user **`vendor_config`**.
    source: &'static str,
}

async fn get_vendors_summary(
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

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct VendorModelTestBody {
    model_name: String,
    /// Legacy field **`type`**: **`text`** | **`image`** | **`video`**.
    #[serde(rename = "type")]
    kind: String,
    id: String,
}

const MAX_VENDOR_MODEL_TEST_FIELD_LEN: usize = 512;

async fn post_vendor_model_test(
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

async fn load_vendor_config(pool: &sqlx::PgPool, uid: Uuid) -> Result<VendorConfig, ApiError> {
    let row: Option<sqlx::types::Json<VendorConfig>> = sqlx::query_scalar(
        r#"
        SELECT vendor_config FROM app_user_profile WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row.map(|j| j.0).unwrap_or_default())
}

async fn save_vendor_config(
    pool: &sqlx::PgPool,
    uid: Uuid,
    cfg: &VendorConfig,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, vendor_config)
        VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE SET vendor_config = $2
        "#,
    )
    .bind(uid)
    .bind(sqlx::types::Json(cfg))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

fn vendor_writes_not_implemented() -> ApiError {
    ApiError::NotImplemented(
        "per-user vendor config and provider scripts are not persisted on the Rust API; use static catalog and server env"
            .into(),
    )
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AddVendorBody {
    ts_code: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateVendorBody {
    id: String,
    /// User-defined display name (optional).
    #[serde(default)]
    display_name: Option<String>,
    /// Selected model IDs from this vendor.
    #[serde(default)]
    selected_models: Vec<String>,
    /// Additional non-sensitive settings key-value pairs.
    #[serde(default)]
    settings: HashMap<String, String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct UpdateVendorResponse {
    vendor_id: String,
    message: &'static str,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DeleteVendorBody {
    id: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct EnableVendorBody {
    id: String,
    enable: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateVendorCodeBody {
    id: String,
    ts_code: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct VendorCodeFromLinkBody {
    link: String,
}

async fn post_add_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddVendorBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(vendor_writes_not_implemented())
}

async fn post_update_vendor(
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

async fn post_delete_vendor(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteVendorBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(vendor_writes_not_implemented())
}

async fn post_enable_vendor(
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

async fn post_update_vendor_code(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateVendorCodeBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(vendor_writes_not_implemented())
}

async fn post_vendor_code_from_link(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VendorCodeFromLinkBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    if body.link.trim().is_empty() {
        return Err(ApiError::BadRequest("link must be non-empty".into()));
    }
    let _ = body;
    Err(vendor_writes_not_implemented())
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct StoreCredentialBody {
    vendor_id: String,
    api_key: Option<String>,
    api_secret: Option<String>,
    api_token: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CredentialResponse {
    vendor_id: String,
    key_hint: Option<String>,
    has_secret: bool,
    has_token: bool,
    message: &'static str,
}

async fn post_store_credential(
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
async fn get_credential(
    State(state): State<AppState>,
    headers: HeaderMap,
    axum::extract::Path(vendor_id): axum::extract::Path<String>,
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

async fn delete_credential(
    State(state): State<AppState>,
    headers: HeaderMap,
    axum::extract::Path(vendor_id): axum::extract::Path<String>,
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

pub fn router() -> Router<AppState> {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vendor_model_test_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<VendorModelTestBody>(
            r#"{"modelName":"gpt-4","type":"text","id":"1","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn vendor_model_test_body_accepts_valid() {
        let b: VendorModelTestBody =
            serde_json::from_str(r#"{"modelName":"gpt-4","type":"text","id":"vendor-1"}"#).unwrap();
        assert_eq!(b.model_name, "gpt-4");
        assert_eq!(b.kind, "text");
        assert_eq!(b.id, "vendor-1");
    }

    #[test]
    fn update_vendor_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<UpdateVendorBody>(
            r#"{"id":"v1","displayName":"Test","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn update_vendor_body_accepts_minimal() {
        let b: UpdateVendorBody = serde_json::from_str(r#"{"id":"v1"}"#).unwrap();
        assert_eq!(b.id, "v1");
        assert_eq!(b.display_name, None);
        assert!(b.selected_models.is_empty());
        assert!(b.settings.is_empty());
    }

    #[test]
    fn update_vendor_body_accepts_full() {
        let b: UpdateVendorBody = serde_json::from_str(
            r#"{"id":"v1","displayName":"My Vendor","selectedModels":["m1","m2"],"settings":{"k1":"v1"}}"#,
        )
        .unwrap();
        assert_eq!(b.id, "v1");
        assert_eq!(b.display_name, Some("My Vendor".to_string()));
        assert_eq!(b.selected_models, vec!["m1", "m2"]);
        assert_eq!(b.settings.get("k1"), Some(&"v1".to_string()));
    }

    #[test]
    fn store_credential_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<StoreCredentialBody>(
            r#"{"vendorId":"v1","apiKey":"k","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn store_credential_body_accepts_minimal() {
        let b: StoreCredentialBody = serde_json::from_str(r#"{"vendorId":"v1"}"#).unwrap();
        assert_eq!(b.vendor_id, "v1");
        assert_eq!(b.api_key, None);
        assert_eq!(b.api_secret, None);
        assert_eq!(b.api_token, None);
    }

    #[test]
    fn store_credential_body_accepts_full() {
        let b: StoreCredentialBody = serde_json::from_str(
            r#"{"vendorId":"v1","apiKey":"key123","apiSecret":"secret456","apiToken":"token789"}"#,
        )
        .unwrap();
        assert_eq!(b.vendor_id, "v1");
        assert_eq!(b.api_key, Some("key123".to_string()));
        assert_eq!(b.api_secret, Some("secret456".to_string()));
        assert_eq!(b.api_token, Some("token789".to_string()));
    }

    #[test]
    fn credential_response_serialize() {
        let resp = CredentialResponse {
            vendor_id: "v1".to_string(),
            key_hint: Some("k***3".to_string()),
            has_secret: true,
            has_token: false,
            message: "Test",
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"vendorId\":\"v1\""));
        assert!(json.contains("\"keyHint\":\"k***3\""));
        assert!(json.contains("\"hasSecret\":true"));
        assert!(json.contains("\"hasToken\":false"));
    }

    #[test]
    fn enable_vendor_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<EnableVendorBody>(r#"{"id":"v1","enable":1,"extra":true}"#);
        assert!(err.is_err());
    }

    #[test]
    fn enable_vendor_body_accepts_valid() {
        let b: EnableVendorBody = serde_json::from_str(r#"{"id":"v1","enable":1}"#).unwrap();
        assert_eq!(b.id, "v1");
        assert_eq!(b.enable, 1);
    }
}
