mod get_plan;
mod set_plan;
mod update_data;

use crate::state::AppState;
use axum::{routing::post, Router};

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/script-agent/get-plan-data",
            post(get_plan::post_get_plan_data),
        )
        .route(
            "/api/v1/script-agent/set-plan-data",
            post(set_plan::post_set_plan_data),
        )
        .route(
            "/api/v1/script-agent/update-data",
            post(update_data::post_update_data),
        )
}
