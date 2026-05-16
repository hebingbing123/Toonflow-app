use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

mod common;
mod extract;
mod mutate;
mod query;

pub(super) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/art-styles/extract-prompt",
            post(extract::extract_style_prompt),
        )
        .route(
            "/api/v1/art-styles",
            get(query::list_art_styles).post(query::create_art_style),
        )
        .route(
            "/api/v1/art-styles/numeric/{numeric_id}",
            get(query::get_art_style_by_numeric_id)
                .patch(mutate::patch_art_style_by_numeric_id)
                .delete(mutate::delete_art_style_by_numeric_id),
        )
        .route(
            "/api/v1/art-styles/numeric/{numeric_id}/cover",
            get(query::get_art_style_cover_by_numeric_id),
        )
}
