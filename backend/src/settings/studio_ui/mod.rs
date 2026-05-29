//! Studio shell UI preferences (pinned projects, etc.).

use axum::{routing::get, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{__path_get_studio_ui_prefs, __path_put_studio_ui_prefs};
pub(crate) use handlers::{get_studio_ui_prefs, put_studio_ui_prefs};

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/settings/studio-ui/prefs",
        get(get_studio_ui_prefs).put(put_studio_ui_prefs),
    )
}
