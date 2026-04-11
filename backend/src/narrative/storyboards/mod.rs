//! 脚本下的分镜 CRUD / 按遗留 ID。

mod dto;
mod handlers;

// Stable path `crate::narrative::storyboards::StoryboardRow` (matches pre-split `pub struct` site).
#[allow(unused_imports)]
pub use dto::StoryboardRow;

pub(super) const ADV_LOCK_STORYBOARD_LEGACY_ID: i64 = 884_422_003;

use axum::routing::get;
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/scripts/legacy/{script_legacy_id}/storyboards",
            get(handlers::list_by_script_legacy).post(handlers::create_under_script_legacy),
        )
        .route(
            "/api/v1/storyboards/legacy/{legacy_id}",
            get(handlers::get_by_legacy)
                .patch(handlers::patch_by_legacy)
                .delete(handlers::delete_by_legacy),
        )
}

#[cfg(test)]
mod tests;
