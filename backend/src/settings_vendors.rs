//! Legacy **`POST /api/setting/vendorConfig/getVendorList`** returned SQLite **`o_vendorConfig`** rows (including **`inputValues`** secrets).
//! SaaS exposes only a **static**, **keyless** vendor summary from the same embedded JSON as **`GET /api/v1/models`**.
//! **`POST …/model-test`** validates the legacy body then **501** (no LLM/OSS probe on this API).

use axum::{extract::State, http::HeaderMap, response::Response, routing::get, Json, Router};
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

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings/vendors/summary", get(get_vendors_summary))
        .route(
            "/api/v1/settings/vendors/model-test",
            axum::routing::post(post_vendor_model_test),
        )
}
