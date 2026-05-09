//! 账户数据导出与删号。
//!
//! - `POST /api/v1/settings/account/export`：入队账户导出 zip
//! - `GET /api/v1/settings/account/exports`：查看最近导出任务
//! - `GET /api/v1/settings/account/exports/{job_id}/file`：下载导出包
//! - `POST /api/v1/settings/account/delete`：强确认后删除当前账户

use axum::{routing::get, routing::post, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_get_account_export_file, __path_get_account_exports, __path_post_account_delete,
    __path_post_account_export,
};
pub(crate) use handlers::{
    get_account_export_file, get_account_exports, post_account_delete, post_account_export,
};
pub(crate) use storage::build_account_export_artifact;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings/account/export", post(post_account_export))
        .route("/api/v1/settings/account/exports", get(get_account_exports))
        .route(
            "/api/v1/settings/account/exports/{job_id}/file",
            get(get_account_export_file),
        )
        .route("/api/v1/settings/account/delete", post(post_account_delete))
}
