//! 观察资产治理 HTTP 处理器和数据模型。

use axum::{
    routing::{patch, post},
    Router,
};

use crate::state::AppState;

mod handlers;
mod types;

#[cfg(test)]
mod tests;

pub(crate) use handlers::{
    __path_archive_observation_asset, __path_create_observation_asset,
    __path_increment_falsified_count, __path_increment_hit_count, __path_list_observation_assets,
    __path_reject_observation_asset, __path_update_observation_asset,
};
pub use types::{
    CreateObservationAssetBody, ListObservationAssetsQuery, ObservationAsset,
    UpdateObservationAssetBody,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/benchmark/observation-assets",
            post(handlers::create_observation_asset).get(handlers::list_observation_assets),
        )
        .route(
            "/api/v1/benchmark/observation-assets/{id}",
            patch(handlers::update_observation_asset),
        )
        .route(
            "/api/v1/benchmark/observation-assets/{id}/archive",
            post(handlers::archive_observation_asset),
        )
        .route(
            "/api/v1/benchmark/observation-assets/{id}/reject",
            post(handlers::reject_observation_asset),
        )
        .route(
            "/api/v1/benchmark/observation-assets/{id}/hit",
            post(handlers::increment_hit_count),
        )
        .route(
            "/api/v1/benchmark/observation-assets/{id}/falsified",
            post(handlers::increment_falsified_count),
        )
}
