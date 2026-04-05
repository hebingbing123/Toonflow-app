//! Legacy **`POST /api/setting/vendorConfig/getVendorList`** returned SQLite **`o_vendorConfig`** rows (including **`inputValues`** secrets).
//! SaaS exposes only a **static**, **keyless** vendor summary from the same embedded JSON as **`GET /api/v1/models`**.

use axum::{extract::State, http::HeaderMap, routing::get, Json, Router};
use serde::Serialize;

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

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/settings/vendors/summary", get(get_vendors_summary))
}
