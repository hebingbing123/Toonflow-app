use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;
use crate::vendor::catalog::vendor_catalog_summaries;

use super::common::require_pool;
use crate::settings::vendors::dto::{VendorSummaryItem, VendorsSummaryResponse};
use crate::settings::vendors::store::load_vendor_config;

#[utoipa::path(
    get,
    path = "/api/v1/settings/vendors/summary",
    operation_id = "getSettingsVendorsSummaryV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_vendors_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<VendorsSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let catalog = vendor_catalog_summaries();

    let user_cfg = match require_pool(&state) {
        Ok(pool) => load_vendor_config(pool, uid).await.ok(),
        Err(_) => None,
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
