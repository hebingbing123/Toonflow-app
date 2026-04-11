//! 脚本下的分镜 CRUD / 按遗留 ID。

mod dto;
mod handlers;

// Stable path `crate::narrative::storyboards::StoryboardRow` (matches pre-split `pub struct` site).
#[allow(unused_imports)]
pub use dto::StoryboardRow;

pub(super) const ADV_LOCK_STORYBOARD_NUMERIC_ID: i64 = 884_422_003;

use axum::routing::get;
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/projects/{project_id}/scripts/{script_numeric_id}/storyboards",
            get(handlers::list_by_script_for_project)
                .post(handlers::create_under_script_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/storyboards/{storyboard_numeric_id}",
            get(handlers::get_by_numeric_id_for_project)
                .patch(handlers::patch_by_numeric_id_for_project)
                .delete(handlers::delete_by_numeric_id_for_project),
        )
}

#[cfg(test)]
mod tests;
