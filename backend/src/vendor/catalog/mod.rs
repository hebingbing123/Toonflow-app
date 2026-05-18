//! 静态模型/提供商目录（编译时 JSON）。
//!
//! 与遗留 `modelSelect/getModelList` 兼容，无需 Postgres `o_vendorConfig` 即可过滤。

use axum::{routing::get, Router};

use crate::state::AppState;

mod data;
mod handlers;
pub(crate) mod pricing;
mod query;
pub(crate) mod types;

#[cfg(test)]
mod tests;

pub(crate) use query::{lookup_vendor_catalog, vendor_catalog_summaries};

pub(crate) use types::{VendorCatalogLookup, VendorCatalogSummary};

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_list_models, __path_model_detail, __path_patch_text_model_default,
    __path_text_model_default, list_models, model_detail, patch_text_model_default,
    text_model_default,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/models", get(handlers::list_models))
        .route(
            "/api/v1/models/text-default",
            get(handlers::text_model_default).patch(handlers::patch_text_model_default),
        )
        .route("/api/v1/models/detail", get(handlers::model_detail))
}
