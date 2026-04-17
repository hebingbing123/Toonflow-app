//! 危险操作模块。
//!
//! 遗留 `POST /api/other/deleteAllData` 和 `GET /api/setting/dbConfig/clearData` 擦除/重建**本地 SQLite**。
//! SaaS：`POST` 端点仅接受 `{}`；需要 **JWT**；响应 **501** — 无批量擦除（使用 Supabase 操作/账户删除流程）。

use axum::{routing::post, Router};

use crate::state::AppState;

mod handlers;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{__path_post_clear_database, __path_post_delete_all_data};
pub(crate) use handlers::{post_clear_database, post_delete_all_data};

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/danger/delete-all-data",
            post(post_delete_all_data),
        )
        .route(
            "/api/v1/settings/danger/clear-database",
            post(post_clear_database),
        )
}

#[cfg(test)]
mod tests {
    use super::handlers::wipe_not_supported;
    use super::types::EmptyDangerBody;
    use crate::error::ApiError;

    #[test]
    fn empty_danger_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<EmptyDangerBody>(r#"{"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn empty_danger_body_accepts_empty() {
        let b: EmptyDangerBody = serde_json::from_str(r#"{}"#).unwrap();
        let _ = b;
    }

    #[test]
    fn wipe_not_supported_returns_not_implemented() {
        let err = wipe_not_supported();
        assert!(matches!(err, ApiError::NotImplemented(_)));
    }
}
