//! Legacy **`POST /api/setting/vendorConfig/getVendorList`** returned SQLite **`o_vendorConfig`** rows (including **`inputValues`** secrets).
//! SaaS exposes only a **static**, **keyless** vendor summary from the same embedded JSON as **`GET /api/v1/models`**.
//! **`POST …/model-test`** validates the legacy body then **501** (no LLM/OSS probe on this API).
//! **`addVendor`** / **`updateVendor`** / **`deleteVendor`** / **`enableVendor`** / **`updateCode`** / **`getCodeByLink`**: validate top-level JSON then **501** (no per-user vendor table, no TS/vm2, no outbound fetch).

use std::collections::HashMap;

use axum::{
    extract::State,
    http::HeaderMap,
    response::Response,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::models_catalog::vendor_catalog_summaries;
use crate::state::AppState;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct VendorsSummaryResponse {
    vendors: Vec<crate::models_catalog::VendorCatalogSummary>,
    /// Always **`static_catalog`** — not per-user **`o_vendorConfig`**.
    source: &'static str,
}

async fn get_vendors_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<VendorsSummaryResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(VendorsSummaryResponse {
        vendors: vendor_catalog_summaries(),
        source: "static_catalog",
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

async fn post_vendor_model_test(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VendorModelTestBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let kind = body.kind.to_ascii_lowercase();
    if kind != "text" && kind != "image" && kind != "video" {
        return Err(ApiError::BadRequest(
            "type must be text, image, or video".into(),
        ));
    }
    if body.model_name.trim().is_empty() || body.id.trim().is_empty() {
        return Err(ApiError::BadRequest(
            "modelName and id must be non-empty".into(),
        ));
    }
    Err(ApiError::NotImplemented(
        "vendor modelTest (live LLM/image/video probe) is not implemented on the Rust API".into(),
    ))
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

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateVendorBody {
    id: String,
    #[serde(default)]
    input_values: HashMap<String, String>,
    inputs: Vec<serde_json::Value>,
    models: Vec<serde_json::Value>,
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
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    if body.id.trim().is_empty() {
        return Err(ApiError::BadRequest("id must be non-empty".into()));
    }
    let _ = body;
    Err(vendor_writes_not_implemented())
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
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body;
    Err(vendor_writes_not_implemented())
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
}
