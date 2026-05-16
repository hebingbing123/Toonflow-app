//! User-scoped API key management.
//!
//! - `GET /api/v1/settings/api-keys`
//! - `GET /api/v1/settings/api-keys/audit`
//! - `POST /api/v1/settings/api-keys`
//! - `POST /api/v1/settings/api-keys/{id}/rotate`
//! - `POST /api/v1/settings/api-keys/{id}/revoke`
//! - `POST /api/v1/settings/api-keys/{id}/activate`
//! - `DELETE /api/v1/settings/api-keys/{id}`

use axum::{
    routing::{delete, get, post},
    Router,
};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_delete_api_key, __path_get_api_key_audit, __path_get_api_keys,
    __path_post_activate_api_key, __path_post_create_api_key, __path_post_revoke_api_key,
    __path_post_rotate_api_key,
};
pub(crate) use handlers::{
    delete_api_key, get_api_key_audit, get_api_keys, post_activate_api_key, post_create_api_key,
    post_revoke_api_key, post_rotate_api_key,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/api-keys",
            get(get_api_keys).post(post_create_api_key),
        )
        .route("/api/v1/settings/api-keys/audit", get(get_api_key_audit))
        .route(
            "/api/v1/settings/api-keys/{id}/rotate",
            post(post_rotate_api_key),
        )
        .route(
            "/api/v1/settings/api-keys/{id}/revoke",
            post(post_revoke_api_key),
        )
        .route(
            "/api/v1/settings/api-keys/{id}/activate",
            post(post_activate_api_key),
        )
        .route("/api/v1/settings/api-keys/{id}", delete(delete_api_key))
}
