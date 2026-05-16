//! Platform config / feature flags.
//!
//! Persists shell and ops toggles in:
//! - `app_user_profile.platform_config` for user overrides
//! - `app_workspace.metadata.platform_config` for workspace overrides

use axum::{routing::get, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{__path_get_platform_config, __path_post_platform_config};
pub(crate) use handlers::{get_platform_config, post_platform_config};
pub use types::{PlatformConfigEnvelope, PlatformConfigResponse, PlatformConfigToggleSet};

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/settings/platform-config",
        get(get_platform_config).post(post_platform_config),
    )
}
