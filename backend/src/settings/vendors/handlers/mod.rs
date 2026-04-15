//! 提供商设置 HTTP 处理器。
//!
//! 提供商列表、配置和模型测试端点。

mod common;
pub(crate) mod credential;
pub(crate) mod model_test;
pub(crate) mod summary;
pub(crate) mod vendor_manage;

use axum::{
    routing::{get, post},
    Router,
};

use crate::state::AppState;

#[allow(unused_imports)]
pub(crate) use credential::{
    __path_delete_credential, __path_get_credential, __path_post_store_credential,
};
pub(crate) use credential::{delete_credential, get_credential, post_store_credential};
#[allow(unused_imports)]
pub(crate) use model_test::__path_post_vendor_model_test;
pub(crate) use model_test::post_vendor_model_test;
#[allow(unused_imports)]
pub(crate) use summary::__path_get_vendors_summary;
pub(crate) use summary::get_vendors_summary;
#[allow(unused_imports)]
pub(crate) use vendor_manage::{
    __path_post_add_vendor, __path_post_delete_vendor, __path_post_enable_vendor,
    __path_post_update_vendor, __path_post_update_vendor_code, __path_post_vendor_code_from_link,
};
pub(crate) use vendor_manage::{
    post_add_vendor, post_delete_vendor, post_enable_vendor, post_update_vendor,
    post_update_vendor_code, post_vendor_code_from_link,
};

pub(super) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings/vendors/summary", get(get_vendors_summary))
        .route(
            "/api/v1/settings/vendors/model-test",
            post(post_vendor_model_test),
        )
        .route("/api/v1/settings/vendors/add", post(post_add_vendor))
        .route("/api/v1/settings/vendors/update", post(post_update_vendor))
        .route("/api/v1/settings/vendors/delete", post(post_delete_vendor))
        .route("/api/v1/settings/vendors/enable", post(post_enable_vendor))
        .route(
            "/api/v1/settings/vendors/update-code",
            post(post_update_vendor_code),
        )
        .route(
            "/api/v1/settings/vendors/code-from-link",
            post(post_vendor_code_from_link),
        )
        .route(
            "/api/v1/settings/vendors/credential",
            post(post_store_credential),
        )
        .route(
            "/api/v1/settings/vendors/credential/{vendor_id}",
            get(get_credential).delete(delete_credential),
        )
}
